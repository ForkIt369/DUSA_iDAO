// Sample implementation of MCP Server Registry API endpoints
// This demonstrates how the core server registration and discovery functionality might be implemented

import { Controller, Get, Post, Put, Delete, Param, Body, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiParam, ApiBody, ApiQuery } from '@nestjs/swagger';
import { AuthGuard } from '../auth/auth.guard';
import { Web3AuthGuard } from '../auth/web3-auth.guard';
import { MCPServerService } from './mcp-server.service';
import { CreateMCPServerDto, UpdateMCPServerDto, MCPServerResponseDto, MCPServerVersionDto } from './dto';
import { PaginationParams } from '../common/pagination.params';
import { User } from '../decorators/user.decorator';
import { UserEntity } from '../users/entities/user.entity';

@ApiTags('MCP Server Registry')
@Controller('api/servers')
export class MCPServerController {
  constructor(private readonly mcpServerService: MCPServerService) {}

  @Post()
  @UseGuards(AuthGuard)
  @ApiOperation({ summary: 'Register a new MCP server' })
  @ApiResponse({ status: 201, description: 'Server registered successfully', type: MCPServerResponseDto })
  @ApiResponse({ status: 400, description: 'Invalid input data' })
  @ApiBody({ type: CreateMCPServerDto })
  async createServer(
    @Body() createServerDto: CreateMCPServerDto,
    @User() user: UserEntity,
  ): Promise<MCPServerResponseDto> {
    return this.mcpServerService.createServer(createServerDto, user.id);
  }

  @Get()
  @ApiOperation({ summary: 'List or search MCP servers' })
  @ApiResponse({ status: 200, description: 'List of MCP servers', type: [MCPServerResponseDto] })
  @ApiQuery({ name: 'search', required: false, description: 'Search term for server name or description' })
  @ApiQuery({ name: 'category', required: false, description: 'Filter by category' })
  @ApiQuery({ name: 'tags', required: false, description: 'Filter by tags (comma-separated)' })
  async listServers(
    @Query('search') search?: string,
    @Query('category') category?: string,
    @Query('tags') tags?: string,
    @Query() paginationParams?: PaginationParams,
  ): Promise<{ data: MCPServerResponseDto[]; total: number; page: number; limit: number }> {
    const tagArray = tags ? tags.split(',').map(tag => tag.trim()) : undefined;
    return this.mcpServerService.findServers(search, category, tagArray, paginationParams);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get MCP server details' })
  @ApiResponse({ status: 200, description: 'Server details', type: MCPServerResponseDto })
  @ApiResponse({ status: 404, description: 'Server not found' })
  @ApiParam({ name: 'id', description: 'Server ID' })
  async getServer(@Param('id') id: string): Promise<MCPServerResponseDto> {
    return this.mcpServerService.findServerById(id);
  }

  @Put(':id')
  @UseGuards(AuthGuard)
  @ApiOperation({ summary: 'Update server metadata' })
  @ApiResponse({ status: 200, description: 'Server updated successfully', type: MCPServerResponseDto })
  @ApiResponse({ status: 403, description: 'Forbidden - not the server owner' })
  @ApiResponse({ status: 404, description: 'Server not found' })
  @ApiParam({ name: 'id', description: 'Server ID' })
  @ApiBody({ type: UpdateMCPServerDto })
  async updateServer(
    @Param('id') id: string,
    @Body() updateServerDto: UpdateMCPServerDto,
    @User() user: UserEntity,
  ): Promise<MCPServerResponseDto> {
    return this.mcpServerService.updateServer(id, updateServerDto, user.id);
  }

  @Delete(':id')
  @UseGuards(AuthGuard)
  @ApiOperation({ summary: 'Remove server' })
  @ApiResponse({ status: 200, description: 'Server removed successfully' })
  @ApiResponse({ status: 403, description: 'Forbidden - not the server owner' })
  @ApiResponse({ status: 404, description: 'Server not found' })
  @ApiParam({ name: 'id', description: 'Server ID' })
  async removeServer(
    @Param('id') id: string,
    @User() user: UserEntity,
  ): Promise<{ success: boolean; message: string }> {
    await this.mcpServerService.removeServer(id, user.id);
    return { success: true, message: 'Server removed successfully' };
  }

  @Post(':id/versions')
  @UseGuards(AuthGuard)
  @ApiOperation({ summary: 'Add new server version' })
  @ApiResponse({ status: 201, description: 'Version added successfully', type: MCPServerVersionDto })
  @ApiResponse({ status: 403, description: 'Forbidden - not the server owner' })
  @ApiResponse({ status: 404, description: 'Server not found' })
  @ApiParam({ name: 'id', description: 'Server ID' })
  @ApiBody({ type: MCPServerVersionDto })
  async addVersion(
    @Param('id') id: string,
    @Body() versionDto: MCPServerVersionDto,
    @User() user: UserEntity,
  ): Promise<MCPServerVersionDto> {
    return this.mcpServerService.addServerVersion(id, versionDto, user.id);
  }

  @Get(':id/versions')
  @ApiOperation({ summary: 'List server versions' })
  @ApiResponse({ status: 200, description: 'List of server versions', type: [MCPServerVersionDto] })
  @ApiResponse({ status: 404, description: 'Server not found' })
  @ApiParam({ name: 'id', description: 'Server ID' })
  async listVersions(@Param('id') id: string): Promise<MCPServerVersionDto[]> {
    return this.mcpServerService.findServerVersions(id);
  }

  @Get(':id/analytics')
  @UseGuards(AuthGuard)
  @ApiOperation({ summary: 'Get server usage analytics' })
  @ApiResponse({ status: 200, description: 'Server analytics' })
  @ApiResponse({ status: 403, description: 'Forbidden - not the server owner' })
  @ApiResponse({ status: 404, description: 'Server not found' })
  @ApiParam({ name: 'id', description: 'Server ID' })
  async getAnalytics(
    @Param('id') id: string,
    @User() user: UserEntity,
    @Query('period') period: 'day' | 'week' | 'month' | 'year' = 'month',
  ): Promise<any> {
    return this.mcpServerService.getServerAnalytics(id, user.id, period);
  }

  @Post(':id/web3/register')
  @UseGuards(Web3AuthGuard)
  @ApiOperation({ summary: 'Register server on blockchain' })
  @ApiResponse({ status: 200, description: 'Server registered on blockchain' })
  @ApiResponse({ status: 403, description: 'Forbidden - not the server owner' })
  @ApiResponse({ status: 404, description: 'Server not found' })
  @ApiParam({ name: 'id', description: 'Server ID' })
  async registerOnBlockchain(
    @Param('id') id: string,
    @User() user: UserEntity,
  ): Promise<{ success: boolean; transactionHash: string; contractAddress: string }> {
    return this.mcpServerService.registerServerOnBlockchain(id, user.id);
  }
}