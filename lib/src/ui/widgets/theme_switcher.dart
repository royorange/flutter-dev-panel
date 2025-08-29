import 'package:flutter/material.dart';
import '../../core/theme_manager.dart';

/// Theme switcher widget
class ThemeSwitcher extends StatelessWidget {
  const ThemeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListenableBuilder(
      listenable: ThemeManager.instance,
      builder: (context, _) {
        final manager = ThemeManager.instance;
        final current = manager.currentTheme;
        final themes = manager.availableThemes;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.palette_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Theme:',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(width: 12),
              
              // Theme selector
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: current.name,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      borderRadius: BorderRadius.circular(8),
                      items: themes.map((themeConfig) {
                        return DropdownMenuItem(
                          value: themeConfig.name,
                          child: Row(
                            children: [
                              _buildThemeIcon(themeConfig),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  themeConfig.name,
                                  style: theme.textTheme.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          final selectedTheme = themes.firstWhere(
                            (t) => t.name == value,
                          );
                          manager.switchTheme(selectedTheme);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildThemeIcon(ThemeConfig theme) {
    IconData icon;
    Color? color;
    
    switch (theme.mode) {
      case ThemeMode.system:
        icon = Icons.settings_suggest;
        color = null;
      case ThemeMode.light:
        icon = Icons.light_mode;
        color = theme.primaryColor;
      case ThemeMode.dark:
        icon = Icons.dark_mode;
        color = theme.primaryColor;
    }
    
    return Icon(
      icon,
      size: 16,
      color: color,
    );
  }
}

/// Compact theme toggle button (for FAB or toolbar)
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});
  
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeManager.instance,
      builder: (context, _) {
        final manager = ThemeManager.instance;
        final isDark = manager.isDarkMode(context);
        
        return IconButton(
          icon: Icon(
            isDark ? Icons.light_mode : Icons.dark_mode,
            size: 20,
          ),
          onPressed: () {
            // Toggle between light and dark
            manager.switchThemeMode(
              isDark ? ThemeMode.light : ThemeMode.dark
            );
          },
          tooltip: isDark ? 'Switch to Light' : 'Switch to Dark',
        );
      },
    );
  }
}