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
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => _showEditDialog(
                                  context,
                                  entry.key,
                                  entry.value,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant,
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

  void _showEditDialog(BuildContext context, String key, dynamic value) {
    showDialog(
      context: context,
      builder: (context) => _EditVariableDialog(
        variableKey: key,
        initialValue: value,
      ),
    );
  }
}

/// Dialog for editing a single environment variable
class _EditVariableDialog extends StatefulWidget {
  final String variableKey;
  final dynamic initialValue;

  const _EditVariableDialog({
    required this.variableKey,
    required this.initialValue,
  });

  @override
  State<_EditVariableDialog> createState() => _EditVariableDialogState();
}

class _EditVariableDialogState extends State<_EditVariableDialog> {
  late TextEditingController _controller;
  late _ValueType _valueType;

  @override
  void initState() {
    super.initState();
    _valueType = _detectValueType(widget.initialValue);
    _controller = TextEditingController(
      text: widget.initialValue.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _ValueType _detectValueType(dynamic value) {
    if (value is bool) return _ValueType.boolean;
    if (value is int) return _ValueType.integer;
    if (value is double) return _ValueType.decimal;
    return _ValueType.string;
  }

  dynamic _parseValue(String text) {
    switch (_valueType) {
      case _ValueType.boolean:
        final lower = text.toLowerCase();
        return lower == 'true' || lower == '1' || lower == 'yes';
      case _ValueType.integer:
        return int.tryParse(text) ?? 0;
      case _ValueType.decimal:
        return double.tryParse(text) ?? 0.0;
      case _ValueType.string:
        return text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('Edit ${widget.variableKey}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Value type indicator
          Text(
            'Type: ${_valueType.name}',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          // Input field
          if (_valueType == _ValueType.boolean)
            DropdownButtonFormField<String>(
              value: _controller.text.toLowerCase() == 'true' ||
                      _controller.text == '1' ||
                      _controller.text.toLowerCase() == 'yes'
                  ? 'true'
                  : 'false',
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'true', child: Text('true')),
                DropdownMenuItem(value: 'false', child: Text('false')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _controller.text = value;
                }
              },
            )
          else
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              keyboardType: _valueType == _ValueType.integer
                  ? TextInputType.number
                  : _valueType == _ValueType.decimal
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
              maxLines: _valueType == _ValueType.string ? 3 : 1,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final newValue = _parseValue(_controller.text);
            EnvironmentManager.instance.updateVariable(
              widget.variableKey,
              newValue,
            );
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

enum _ValueType { string, integer, decimal, boolean }