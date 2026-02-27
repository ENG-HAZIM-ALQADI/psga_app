import 'package:flutter/material.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/utils/extensions.dart';

/// شريط بحث جهات الاتصال
class ContactSearchBar extends StatefulWidget {
  final Function(String) onSearch;
  final VoidCallback? onClear;
  final String? hintText;
  final bool autofocus;

  const ContactSearchBar({
    required this.onSearch,
    this.onClear,
    this.hintText,
    this.autofocus = false,
    super.key,
  });

  @override
  State<ContactSearchBar> createState() => _ContactSearchBarState();
}

class _ContactSearchBarState extends State<ContactSearchBar> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _hasText = _controller.text.isNotEmpty;
    });
    widget.onSearch(_controller.text);
  }

  void _clear() {
    _controller.clear();
    widget.onClear?.call();
    widget.onSearch('');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        decoration: InputDecoration(
          hintText: widget.hintText ?? context.l10n.searchContact,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _hasText
              ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clear,
                      tooltip: context.l10n.clearSearch,
                    )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: widget.onSearch,
      ),
    );
  }
}

/// شريط بحث مع فلتر الطوارئ
class ContactSearchBarWithFilter extends StatefulWidget {
  final Function(String) onSearch;
  final Function(bool) onEmergencyFilter;
  final VoidCallback? onClear;
  final bool showEmergencyOnly;

  const ContactSearchBarWithFilter({
    required this.onSearch,
    required this.onEmergencyFilter,
    this.onClear,
    this.showEmergencyOnly = false,
    super.key,
  });

  @override
  State<ContactSearchBarWithFilter> createState() =>
      _ContactSearchBarWithFilterState();
}

class _ContactSearchBarWithFilterState
    extends State<ContactSearchBarWithFilter> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;
  late bool _emergencyOnly;

  @override
  void initState() {
    super.initState();
    _emergencyOnly = widget.showEmergencyOnly;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _hasText = _controller.text.isNotEmpty;
    });
    widget.onSearch(_controller.text);
  }

  void _clear() {
    _controller.clear();
    widget.onClear?.call();
    widget.onSearch('');
  }

  void _toggleEmergencyFilter() {
    setState(() {
      _emergencyOnly = !_emergencyOnly;
    });
    widget.onEmergencyFilter(_emergencyOnly);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // شريط البحث
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: context.l10n.searchContact,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _hasText
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clear,
                      tooltip: context.l10n.clearSearch,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: widget.onSearch,
          ),
        ),

        // فلتر الطوارئ
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              FilterChip(
                label: Text(context.l10n.emergencyContactsOnly),
                selected: _emergencyOnly,
                onSelected: (selected) => _toggleEmergencyFilter(),
                avatar: Icon(
                  Icons.emergency,
                  size: 18,
                  color: _emergencyOnly ? Colors.white : AppColors.red,
                ),
                selectedColor: AppColors.red,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: _emergencyOnly ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
