import 'package:flutter/material.dart';
import '../../core/environment_manager.dart';

/// Environment switcher widget
class EnvironmentSwitcher extends StatelessWidget {
  const EnvironmentSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListenableBuilder(
      listenable: EnvironmentManager.instance,
      builder: (context, _) {
        final manager = EnvironmentManager.instance;
        final current = manager.currentEnvironment;
        final environments = manager.environments;
        
        if (environments.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.dns,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 0,
                child: Text(
                  'Env:',
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              
              // Environment selector
              Expanded(
                child: Container(
                  height: 32,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: current?.name,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      borderRadius: BorderRadius.circular(8),
                      items: environments.map((env) {
                        return DropdownMenuItem(
                          value: env.name,
                          child: Text(
                            env.name,
                            style: theme.textTheme.bodyMedium,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          manager.switchEnvironment(value);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Switched to $value'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // View/Edit variables button
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 20),
                onPressed: () => _showEnvironmentVariables(context),
                tooltip: 'View Variables',
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _showEnvironmentVariables(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const EnvironmentVariablesDialog(),
    );
  }
}

/// Environment variables dialog
class EnvironmentVariablesDialog extends StatefulWidget {
  const EnvironmentVariablesDialog({super.key});

  @override
  State<EnvironmentVariablesDialog> createState() => _EnvironmentVariablesDialogState();
}

class _EnvironmentVariablesDialogState extends State<EnvironmentVariablesDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manager = EnvironmentManager.instance;
    
    final current = manager.currentEnvironment;
    
    return AlertDialog(
      title: Text('${current?.name ?? "No Environment"} Variables'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListenableBuilder(
          listenable: manager,
          builder: (context, _) {
            if (current == null) {
              return const Center(
                child: Text('No environment selected'),
              );
            }
            
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Variables list
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: current.variables.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 120,
                                child: Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: SelectableText(
                                  entry.value.toString(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
  
}