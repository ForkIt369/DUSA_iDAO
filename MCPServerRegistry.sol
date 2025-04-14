// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title MCPServerRegistry
 * @dev Smart contract for registering and verifying MCP servers on-chain
 */
contract MCPServerRegistry {
    // Events
    event ServerRegistered(string serverId, address owner, string metadataURI);
    event ServerUpdated(string serverId, string metadataURI);
    event ServerVerified(string serverId, address verifier);
    event OwnershipTransferred(string serverId, address previousOwner, address newOwner);

    // Structs
    struct ServerInfo {
        address owner;
        string metadataURI;
        uint256 registrationTime;
        uint256 lastUpdateTime;
        bool verified;
        uint256 verificationCount;
        mapping(address => bool) verifiers;
    }

    // State variables
    mapping(string => ServerInfo) private servers;
    mapping(address => string[]) private ownerServers;
    address private governance;
    address[] private verifiers;
    mapping(address => bool) private isVerifier;
    uint256 private verifierThreshold;

    // Modifiers
    modifier onlyGovernance() {
        require(msg.sender == governance, "MCPServerRegistry: caller is not governance");
        _;
    }

    modifier onlyServerOwner(string memory serverId) {
        require(servers[serverId].owner == msg.sender, "MCPServerRegistry: caller is not server owner");
        _;
    }

    modifier onlyVerifier() {
        require(isVerifier[msg.sender], "MCPServerRegistry: caller is not a verifier");
        _;
    }

    modifier serverExists(string memory serverId) {
        require(servers[serverId].owner != address(0), "MCPServerRegistry: server does not exist");
        _;
    }

    /**
     * @dev Constructor
     * @param _governance Address of the governance contract or multisig
     * @param _initialVerifiers Array of initial verifier addresses
     * @param _verifierThreshold Minimum number of verifications required
     */
    constructor(address _governance, address[] memory _initialVerifiers, uint256 _verifierThreshold) {
        governance = _governance;
        verifierThreshold = _verifierThreshold;
        
        for (uint256 i = 0; i < _initialVerifiers.length; i++) {
            verifiers.push(_initialVerifiers[i]);
            isVerifier[_initialVerifiers[i]] = true;
        }
    }

    /**
     * @dev Register a new MCP server
     * @param serverId Unique identifier for the server
     * @param metadataURI URI pointing to the server metadata (IPFS/Arweave)
     */
    function registerServer(string memory serverId, string memory metadataURI) external {
        require(servers[serverId].owner == address(0), "MCPServerRegistry: server already registered");
        
        ServerInfo storage newServer = servers[serverId];
        newServer.owner = msg.sender;
        newServer.metadataURI = metadataURI;
        newServer.registrationTime = block.timestamp;
        newServer.lastUpdateTime = block.timestamp;
        newServer.verified = false;
        newServer.verificationCount = 0;
        
        ownerServers[msg.sender].push(serverId);
        
        emit ServerRegistered(serverId, msg.sender, metadataURI);
    }

    /**
     * @dev Update server metadata
     * @param serverId Unique identifier for the server
     * @param metadataURI New URI pointing to the server metadata
     */
    function updateServerMetadata(string memory serverId, string memory metadataURI) 
        external 
        serverExists(serverId)
        onlyServerOwner(serverId)
    {
        servers[serverId].metadataURI = metadataURI;
        servers[serverId].lastUpdateTime = block.timestamp;
        
        emit ServerUpdated(serverId, metadataURI);
    }

    /**
     * @dev Verify a server (only callable by verifiers)
     * @param serverId Unique identifier for the server
     */
    function verifyServer(string memory serverId) 
        external 
        serverExists(serverId)
        onlyVerifier
    {
        ServerInfo storage server = servers[serverId];
        require(!server.verifiers[msg.sender], "MCPServerRegistry: already verified by this verifier");
        
        server.verifiers[msg.sender] = true;
        server.verificationCount += 1;
        
        if (server.verificationCount >= verifierThreshold && !server.verified) {
            server.verified = true;
        }
        
        emit ServerVerified(serverId, msg.sender);
    }

    /**
     * @dev Transfer ownership of a server
     * @param serverId Unique identifier for the server
     * @param newOwner Address of the new owner
     */
    function transferOwnership(string memory serverId, address newOwner) 
        external 
        serverExists(serverId)
        onlyServerOwner(serverId)
    {
        require(newOwner != address(0), "MCPServerRegistry: new owner is the zero address");
        
        address previousOwner = servers[serverId].owner;
        servers[serverId].owner = newOwner;
        
        // Remove from previous owner's list
        removeServerFromOwnerList(previousOwner, serverId);
        
        // Add to new owner's list
        ownerServers[newOwner].push(serverId);
        
        emit OwnershipTransferred(serverId, previousOwner, newOwner);
    }

    /**
     * @dev Add a new verifier
     * @param verifier Address of the new verifier
     */
    function addVerifier(address verifier) external onlyGovernance {
        require(!isVerifier[verifier], "MCPServerRegistry: already a verifier");
        
        verifiers.push(verifier);
        isVerifier[verifier] = true;
    }

    /**
     * @dev Remove a verifier
     * @param verifier Address of the verifier to remove
     */
    function removeVerifier(address verifier) external onlyGovernance {
        require(isVerifier[verifier], "MCPServerRegistry: not a verifier");
        
        isVerifier[verifier] = false;
        
        // Remove from verifiers array
        for (uint256 i = 0; i < verifiers.length; i++) {
            if (verifiers[i] == verifier) {
                verifiers[i] = verifiers[verifiers.length - 1];
                verifiers.pop();
                break;
            }
        }
    }

    /**
     * @dev Update verifier threshold
     * @param newThreshold New threshold value
     */
    function updateVerifierThreshold(uint256 newThreshold) external onlyGovernance {
        require(newThreshold > 0, "MCPServerRegistry: threshold must be greater than 0");
        verifierThreshold = newThreshold;
    }

    /**
     * @dev Get server information
     * @param serverId Unique identifier for the server
     * @return owner Server owner address
     * @return metadataURI Server metadata URI
     * @return registrationTime Server registration timestamp
     * @return lastUpdateTime Last update timestamp
     * @return verified Whether the server is verified
     * @return verificationCount Number of verifications
     */
    function getServerInfo(string memory serverId) 
        external 
        view 
        serverExists(serverId)
        returns (
            address owner,
            string memory metadataURI,
            uint256 registrationTime,
            uint256 lastUpdateTime,
            bool verified,
            uint256 verificationCount
        ) 
    {
        ServerInfo storage server = servers[serverId];
        return (
            server.owner,
            server.metadataURI,
            server.registrationTime,
            server.lastUpdateTime,
            server.verified,
            server.verificationCount
        );
    }

    /**
     * @dev Check if a server is verified by a specific verifier
     * @param serverId Unique identifier for the server
     * @param verifier Address of the verifier
     * @return True if verified by the specified verifier
     */
    function isServerVerifiedBy(string memory serverId, address verifier) 
        external 
        view 
        serverExists(serverId)
        returns (bool) 
    {
        return servers[serverId].verifiers[verifier];
    }

    /**
     * @dev Get all servers owned by an address
     * @param owner Address of the owner
     * @return Array of server IDs
     */
    function getServersByOwner(address owner) external view returns (string[] memory) {
        return ownerServers[owner];
    }

    /**
     * @dev Get all verifiers
     * @return Array of verifier addresses
     */
    function getVerifiers() external view returns (address[] memory) {
        return verifiers;
    }

    /**
     * @dev Get current verifier threshold
     * @return Current threshold value
     */
    function getVerifierThreshold() external view returns (uint256) {
        return verifierThreshold;
    }

    /**
     * @dev Helper function to remove a server from an owner's list
     * @param owner Address of the owner
     * @param serverId Server ID to remove
     */
    function removeServerFromOwnerList(address owner, string memory serverId) private {
        string[] storage ownerServerList = ownerServers[owner];
        
        for (uint256 i = 0; i < ownerServerList.length; i++) {
            if (keccak256(bytes(ownerServerList[i])) == keccak256(bytes(serverId))) {
                // Move the last element to the position of the element to delete
                ownerServerList[i] = ownerServerList[ownerServerList.length - 1];
                // Remove the last element
                ownerServerList.pop();
                break;
            }
        }
    }
}