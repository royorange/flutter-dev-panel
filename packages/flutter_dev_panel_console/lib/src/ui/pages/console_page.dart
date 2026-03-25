import 'package:flutter/material.dart';
import 'package:flutter_dev_panel/flutter_dev_panel.dart';
import '../../providers/console_provider.dart';
import '../widgets/log_item.dart';
import '../widgets/log_filter_bar.dart';

/// Console log page
class ConsolePage extends StatefulWidget {
  const ConsolePage({super.key});

  @override
  State<ConsolePage> createState() => _ConsolePageState();
}

class _ConsolePageState extends State<ConsolePage> {
  late final ConsoleProvider provider;
  final _searchFocusNode = FocusNode();
  final _searchController = TextEditingController();
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    provider = ConsoleProvider();
    _searchFocusNode.addListener(() {
      if (_isSearchFocused != _searchFocusNode.hasFocus) {
        setState(() {
          _isSearchFocused = _searchFocusNode.hasFocus;
        });
      }
    });

    // 页面打开时如果启用了自动滚动，延迟滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.autoScroll && provider.scrollController.hasClients) {
        provider.scrollController.jumpTo(
          provider.scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  @override
  void dispose() {
    provider.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      resizeToAvoidBottomInset: false, // Don't resize for keyboard
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Check available height
            final hasEnoughSpace = constraints.maxHeight > 200;

            return Column(
              children: [
                // Top toolbar - always visible
                _buildToolbar(context),

                // Filter bar - only show when there's enough space
                if (hasEnoughSpace) LogFilterBar(provider: provider),

                // Log list - use Expanded to fill all remaining space
                Expanded(
                  child: ListenableBuilder(
                    listenable: provider,
                    builder: (context, _) {
                      if (provider.filteredLogs.isEmpty) {
                        return _buildEmptyState(context);
                      }

                      return ListView.builder(
                        controller: provider.scrollController,
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: provider.filteredLogs.length,
                        itemBuilder: (context, index) {
                          final log = provider.filteredLogs[index];
                          return LogItem(
                            key: ValueKey(
                                '${log.timestamp.millisecondsSinceEpoch}_$index'),
                            log: log,
                            provider: provider,
                          );
                        },
                      );
                    },
                  ),
                ),

                // Bottom status bar - only show when there's enough space
                if (hasEnoughSpace) _buildStatusBar(context),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Build top toolbar
  Widget _buildToolbar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Search box
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(
                  color: _isSearchFocused
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  width: _isSearchFocused ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // During folding animation, width might be very small
                  if (constraints.maxWidth < 50) {
                    // Just show search icon when space is too small
                    return Center(
                      child: Icon(
                        Icons.search,
                        size: 18,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    );
                  }

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search,
                        size: 18,
                        color: _isSearchFocused
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: (value) {
                            provider.setSearchText(value);
                          },
                          textInputAction: TextInputAction.search,
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            hintText: 'Search logs...',
                            hintStyle: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.3),
                            ),
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
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      ListenableBuilder(
                        listenable: provider,
                        builder: (context, _) {
                          if (provider.searchText.isNotEmpty) {
                            return IconButton(
                              icon: Icon(
                                Icons.clear,
                                size: 18,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                _searchController.clear();
                                provider.setSearchText('');
                              },
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Pause/Resume button
          ListenableBuilder(
            listenable: provider,
            builder: (context, _) {
              return IconButton(
                icon: Icon(
                  provider.isPaused ? Icons.play_arrow : Icons.pause,
                  size: 20,
                ),
                onPressed: provider.togglePause,
                tooltip: provider.isPaused ? 'Resume' : 'Pause',
              );
            },
          ),

          // Settings button
          IconButton(
            icon: const Icon(Icons.settings, size: 20),
            onPressed: () => _showLogConfigDialog(context),
            tooltip: 'Log capture settings',
          ),

          // Clear button
          IconButton(
            icon: const Icon(Icons.clear_all, size: 20),
            onPressed: () => _showClearConfirmDialog(context),
            tooltip: 'Clear logs',
          ),
        ],
      ),
    );
  }

  /// Build empty state view
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No logs yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Waiting for logs...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  /// Build bottom status bar
  Widget _buildStatusBar(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: 8 + bottomPadding,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: ListenableBuilder(
        listenable: provider,
        builder: (context, _) {
          final stats = provider.getLogStatistics();
          return Row(
            children: [
              // Log statistics - 使用 Wrap 防止溢出
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatChip(
                        context,
                        count: stats[LogLevel.error] ?? 0,
                        color: Colors.red,
                        icon: Icons.error_outline,
                      ),
                      if (stats[LogLevel.error] != null &&
                          stats[LogLevel.error]! > 0)
                        const SizedBox(width: 8),
                      _buildStatChip(
                        context,
                        count: stats[LogLevel.warning] ?? 0,
                        color: Colors.orange,
                        icon: Icons.warning_amber,
                      ),
                      if (stats[LogLevel.warning] != null &&
                          stats[LogLevel.warning]! > 0)
                        const SizedBox(width: 8),
                      _buildStatChip(
                        context,
                        count: stats[LogLevel.info] ?? 0,
                        color: Colors.green,
                        icon: Icons.info_outline,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Total log count
              Text(
                'Total: ${provider.filteredLogs.length} / ${provider.logs.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Build statistics chip
  Widget _buildStatChip(
    BuildContext context, {
    required int count,
    required Color color,
    required IconData icon,
  }) {
    if (count == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Show clear confirmation dialog
  void _showClearConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text(
            'Are you sure you want to clear all logs? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.clearLogs();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logs cleared'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  /// Show log configuration dialog
  void _showLogConfigDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentConfig = DevLogger.instance.config;

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.settings, size: 24),
                  SizedBox(width: 8),
                  Text('Log Capture Settings'),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Log capture settings
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Log Capture Settings',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Note: Errors are always captured automatically

                              // Auto scroll
                              _buildConfigSwitch(
                                title: 'Auto Scroll',
                                subtitle: 'Automatically scroll to new logs',
                                value: provider.autoScroll,
                                onChanged: (value) {
                                  provider.toggleAutoScroll();
                                  setDialogState(() {});
                                },
                              ),

                              // Combine Logger output
                              _buildConfigSwitch(
                                title: 'Optimize Logger Display',
                                subtitle:
                                    'Combine multi-line Logger package output',
                                value: currentConfig.combineLoggerOutput,
                                onChanged: (value) {
                                  DevLogger.instance.updateConfig(
                                    currentConfig.copyWith(
                                        combineLoggerOutput: value),
                                  );
                                  setDialogState(() {});
                                },
                              ),

                              const Divider(height: 24),

                              // Max logs setting
                              ListTile(
                                title: const Text('Maximum Logs',
                                    style: TextStyle(fontSize: 14)),
                                subtitle: Text(
                                  'Current: ${currentConfig.maxLogs} logs',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: SizedBox(
                                  width: 120,
                                  child: DropdownButton<int>(
                                    value: currentConfig.maxLogs,
                                    isExpanded: true,
                                    items: const [
                                      DropdownMenuItem(
                                          value: 100, child: Text('100')),
                                      DropdownMenuItem(
                                          value: 500, child: Text('500')),
                                      DropdownMenuItem(
                                          value: 1000, child: Text('1000')),
                                      DropdownMenuItem(
                                          value: 2000, child: Text('2000')),
                                      DropdownMenuItem(
                                          value: 5000, child: Text('5000')),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        DevLogger.instance.updateConfig(
                                          currentConfig.copyWith(
                                              maxLogs: value),
                                        );
                                        setDialogState(() {});
                                      }
                                    },
                                  ),
                                ),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Info about what gets captured
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'What gets captured:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• print() and debugPrint() statements\n'
                              '• Logger package output (automatic)\n'
                              '• Flutter errors (RenderFlex overflow, etc.)\n'
                              '• Uncaught async errors\n'
                              '• Developer.log() calls\n\n'
                              'Note: Flutter framework internal logs (like "Reloaded") '
                              'are not captured as they don\'t go through print/Zone.',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Build config switch item
  Widget _buildConfigSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}
