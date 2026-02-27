import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/features/alerts/domain/entities/contact_entity.dart';
import 'package:psga_app/features/alerts/presentation/bloc/contact/contact_bloc.dart';
import 'package:psga_app/features/alerts/presentation/bloc/contact/contact_event.dart';
import 'package:psga_app/features/alerts/presentation/bloc/contact/contact_state.dart';
import 'package:psga_app/features/alerts/presentation/pages/add_contact_page.dart';
import 'package:psga_app/features/alerts/presentation/widgets/contact_card_widget.dart';
import 'package:psga_app/features/alerts/presentation/widgets/contact_search_bar.dart';

/// صفحة إدارة جهات الاتصال الموثوقة
class ContactsPage extends StatefulWidget {
  final String userId;

  const ContactsPage({
    required this.userId,
    super.key,
  });

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  bool _showEmergencyOnly = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // إعادة تحميل جهات الاتصال عند العودة للشاشة
    _loadContacts();
  }

  void _loadContacts() {
    if (_showEmergencyOnly) {
      context.read<ContactBloc>().add(LoadEmergencyContactsEvent(widget.userId));
    } else {
      context.read<ContactBloc>().add(LoadContactsEvent(widget.userId));
    }
  }

  void _searchContacts(String query) {
    if (query.isEmpty) {
      _loadContacts();
    } else {
      context.read<ContactBloc>().add(SearchContactsEvent(
        userId: widget.userId,
        query: query,
      ));
    }
  }

  void _toggleEmergencyFilter() {
    setState(() {
      _showEmergencyOnly = !_showEmergencyOnly;
    });
    _loadContacts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.contacts),
        actions: [
          // Emergency Filter Toggle
          IconButton(
            icon: Icon(
              _showEmergencyOnly ? Icons.emergency : Icons.emergency_outlined,
              color: _showEmergencyOnly ? AppColors.red : Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: _toggleEmergencyFilter,
            tooltip: _showEmergencyOnly ? AppLocalizations.of(context)!.showAll : AppLocalizations.of(context)!.showEmergencyOnly,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          ContactSearchBar(
            onSearch: _searchContacts,
            hintText: AppLocalizations.of(context)!.contactsSearchHint,
          ),
          
          // Content
          Expanded(
            child: BlocConsumer<ContactBloc, ContactState>(
              // ✅ تجاهل ContactsExistCheckState لمنع اختفاء القائمة عند التحقق من جهات الاتصال
              buildWhen: (previous, current) {
                return current is! ContactsExistCheckState;
              },
              listener: (context, state) {
                if (state is ContactError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                } else if (state is ContactAdded) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.contactAdded),
                      backgroundColor: AppColors.green,
                    ),
                  );
                  _loadContacts();
                } else if (state is ContactDeleted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.contactDeleted),
                    ),
                  );
                  _loadContacts();
                } else if (state is PrimaryContactSet) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.setPrimaryContactSuccess),
                      backgroundColor: AppColors.green,
                    ),
                  );
                  _loadContacts();
                }
              },
              builder: (context, state) {
                if (state is ContactLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<ContactEntity> contacts = [];
                
                if (state is ContactsLoaded) {
                  contacts = state.contacts;
                } else if (state is EmergencyContactsLoaded) {
                  contacts = state.contacts;
                } else if (state is ContactSearchResults) {
                  contacts = state.results;
                }

                if (contacts.isEmpty) {
                  return _buildEmptyState();
                }

                // ترتيب حسب الأولوية
                final sortedContacts = List<ContactEntity>.from(contacts)
                  ..sort((a, b) {
                    // الطوارئ أولاً
                    if (a.isPrimary && !b.isPrimary) return -1;
                    if (!a.isPrimary && b.isPrimary) return 1;
                    // ثم حسب الأولوية
                    return a.priority.compareTo(b.priority);
                  });

                return RefreshIndicator(
                  onRefresh: () async => _loadContacts(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // إحصائيات
                      _buildStatsCard(sortedContacts),
                      const SizedBox(height: 16),

                      // قائمة جهات الاتصال
                      ...sortedContacts.map((contact) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ContactCardWidget(
                              contact: contact,
                              onTap: () => _editContact(contact),
                              onEdit: () => _editContact(contact),
                              onDelete: () => _deleteContact(contact),
                            ),
                          )),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addContact,
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: const Icon(Icons.person_add),
        label: Text(AppLocalizations.of(context)!.addContact),
      ),
    );
  }

  Widget _buildStatsCard(List<ContactEntity> contacts) {
    final primaryCount = contacts.where((c) => c.isPrimary).length;
    final smsEnabledCount = contacts.where((c) => c.canSendSMS).length;
    final emergencyCount = contacts.where((c) => c.type == ContactType.emergency).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.contactsStatsTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(AppLocalizations.of(context)!.statTotal, contacts.length.toString(), Icons.people),
              _buildStatItem(AppLocalizations.of(context)!.statEmergency, emergencyCount.toString(), Icons.emergency),
              _buildStatItem(AppLocalizations.of(context)!.statSms, smsEnabledCount.toString(), Icons.sms),
              _buildStatItem(AppLocalizations.of(context)!.statPriority, primaryCount.toString(), Icons.star),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_add_outlined,
            size: 100,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noContactsTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.noContactsSubtitle,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addContact,
            icon: const Icon(Icons.person_add),
            label: Text(AppLocalizations.of(context)!.addFirstContact),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _addContact() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: context.read<ContactBloc>(),
          child: AddContactPage(userId: widget.userId),
        ),
      ),
    );

    if (result == true) {
      _loadContacts();
    }
  }

  void _editContact(ContactEntity contact) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: context.read<ContactBloc>(),
          child: AddContactPage(
            userId: widget.userId,
            contact: contact,
          ),
        ),
      ),
    );

    if (result == true) {
      _loadContacts();
    }
  }

  void _deleteContact(ContactEntity contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.confirmDeleteTitle),
        content: Text(AppLocalizations.of(context)!.deleteContactConfirm(contact.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ContactBloc>().add(DeleteContactEvent(contact.id));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }



  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.infoTitle),
        content: Text(AppLocalizations.of(context)!.contactsInfoBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }
}
