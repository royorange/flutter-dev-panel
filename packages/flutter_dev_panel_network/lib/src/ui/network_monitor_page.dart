import 'package:flutter/material.dart';
import '../network_monitor_controller.dart';
import '../models/network_request.dart';
import 'widgets/request_list_item.dart';
import 'widgets/request_detail_dialog.dart';

class NetworkMonitorPage extends StatefulWidget {
  final NetworkMonitorController controller;

  const NetworkMonitorPage({
    super.key,
    required this.controller,
  });

  @override
  State<NetworkMonitorPage> createState() => _NetworkMonitorPageState();
}

class _NetworkMonitorPageState extends State<NetworkMonitorPage> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.controller.filter.searchQuery ?? '';
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    widget.controller.updateSearchQuery(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          _buildToolbar(theme),
          _buildStatsBar(theme),
          Expanded(
            child: _buildRequestsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: _isSearchFocused
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: _isSearchFocused ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            Icons.search,
                            size: 18,
                            color: _isSearchFocused
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            decoration: const InputDecoration(
                              hintText: 'Search...',
                              hintStyle: TextStyle(fontSize: 13),
                              filled: true,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _searchController,
                          builder: (context, value, _) {
                            if (value.text.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return GestureDetector(
                              onTap: () {
                                _searchController.clear();
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.clear, size: 16),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildActionButtons(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: _buildFilterButtons(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButtons() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              FilterChip(
                label: const Text(
                  'Errors Only',
                  style: TextStyle(fontSize: 12),
                ),
                selected: widget.controller.filter.showOnlyErrors,
                onSelected: (selected) {
                  widget.controller.setShowOnlyErrors(selected);
                },
                avatar: widget.controller.filter.showOnlyErrors
                    ? const Icon(Icons.check, size: 14)
                    : null,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<RequestMethod?>(
                tooltip: 'Filter by method',
                child: Chip(
                  label: Text(
                    widget.controller.filter.method?.name.toUpperCase() ??
                        'All Methods',
                    style: const TextStyle(fontSize: 12),
                  ),
                  avatar: const Icon(Icons.filter_list, size: 14),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: null,
                    child: Text('All Methods'),
                  ),
                  const PopupMenuDivider(),
                  ...RequestMethod.values.map((method) => PopupMenuItem(
                        value: method,
                        child: Text(method.name.toUpperCase()),
                      )),
                ],
                onSelected: (method) {
                  widget.controller.setMethodFilter(method);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                widget.controller.isPaused ? Icons.play_arrow : Icons.pause,
                size: 20,
              ),
              iconSize: 20,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              tooltip: widget.controller.isPaused ? 'Resume' : 'Pause',
              onPressed: widget.controller.togglePause,
            ),
            IconButton(
              icon: const Icon(Icons.clear_all, size: 20),
              iconSize: 20,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              tooltip: 'Clear all',
              onPressed: widget.controller.requests.isEmpty
                  ? null
                  : () => _showClearConfirmation(context),
            ),
            IconButton(
              icon: const Icon(Icons.settings, size: 20),
              iconSize: 20,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              tooltip: 'Settings',
              onPressed: () => _showSettingsDialog(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsBar(ThemeData theme) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatChip(
                  'Total',
                  widget.controller.totalRequests,
                  Icons.list,
                  theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                _buildStatChip(
                  'Success',
                  widget.controller.successCount,
                  Icons.check_circle,
                  Colors.green,
                ),
                const SizedBox(width: 12),
                _buildStatChip(
                  'Errors',
                  widget.controller.errorCount,
                  Icons.error,
                  Colors.red,
                ),
                const SizedBox(width: 12),
                _buildStatChip(
                  'Pending',
                  widget.controller.pendingCount,
                  Icons.hourglass_empty,
                  Colors.orange,
                ),
                if (widget.controller.filter.hasActiveFilters) ...[
                  const SizedBox(width: 16),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      widget.controller.clearFilters();
                      _searchController.clear();
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.clear, size: 14),
                        SizedBox(width: 4),
                        Text('Clear', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatChip(String label, int count, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsList() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final requests = widget.controller.requests;

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.controller.filter.hasActiveFilters
                      ? 'No requests match the current filters'
                      : 'No network requests yet',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return RequestListItem(
              key: ValueKey(request.id),
              request: request,
              onTap: () => _showRequestDetail(context, request),
            );
          },
        );
      },
    );
  }

  void _showRequestDetail(BuildContext context, NetworkRequest request) {
    showDialog(
      context: context,
      builder: (context) => RequestDetailDialog(request: request),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Requests'),
        content:
            const Text('Are you sure you want to clear all network requests?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              widget.controller.clearRequests();
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Network Monitor Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Maximum Requests'),
              subtitle: Text('Currently: ${widget.controller.maxRequests}'),
              trailing: SizedBox(
                width: 100,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  controller: TextEditingController(
                    text: widget.controller.maxRequests.toString(),
                  ),
                  onSubmitted: (value) {
                    final max = int.tryParse(value);
                    if (max != null && max > 0) {
                      widget.controller.setMaxRequests(max);
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
