import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/civic_failure.dart';
import '../../models/domain_models.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_widgets.dart';

/// Uses server filters and pagination; never treats the controller cache as a full listing.
class ConnectedProjectList extends StatefulWidget {
  const ConnectedProjectList({
    super.key,
    required this.onOpen,
    this.action,
    this.title = 'Public projects',
    this.onCreate,
  });
  final Future<void> Function(Project) onOpen;
  final Widget? action;
  final Future<void> Function()? onCreate;
  final String title;
  @override
  State<ConnectedProjectList> createState() => _ConnectedProjectListState();
}

class _ConnectedProjectListState extends State<ConnectedProjectList> {
  final _search = TextEditingController();
  Timer? _debounce;
  ProjectStatus? _status;
  String _sort = 'Latest';
  final List<String> _ids = [];
  int _total = 0;
  int _offset = 0;
  int _request = 0;
  bool _loading = false;
  int? _dataRevision;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = AppScope.of(context).dataRevision;
    if (_dataRevision != revision) {
      _dataRevision = revision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load({bool more = false}) async {
    final request = ++_request;
    final controller = AppScope.of(context);
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _ids.clear();
        _offset = 0;
        _total = 0;
      }
    });
    try {
      final page = await controller.searchProjects(
        search: _search.text,
        status: _status,
        sort: _sort,
        offset: _offset,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _ids.addAll(
          page.projects.map((p) => p.id).where((id) => !_ids.contains(id)),
        );
        _offset += page.projects.length;
        _total = page.total;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = error is CivicFailure
            ? error.message
            : 'Unable to load projects. Please try again.';
      });
    }
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    ++_request;
    setState(() {
      _ids.clear();
      _offset = 0;
      _total = 0;
      _loading = true;
      _error = null;
    });
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return ResponsivePage(
      child: ListView.builder(
        itemCount: 1 + _ids.length + (_offset < _total ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  icon: Icons.account_tree_outlined,
                  title: widget.title,
                  subtitle: 'Projects in ${controller.authorityName}',
                  action: widget.onCreate == null
                      ? widget.action
                      : FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('New project'),
                          onPressed: () async {
                            await widget.onCreate!();
                            if (mounted) _load();
                          },
                        ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  maxLength: 200,
                  onChanged: _searchChanged,
                  decoration: const InputDecoration(
                    hintText: 'Search projects by title, category or location',
                    prefixIcon: Icon(Icons.search),
                    counterText: '',
                  ),
                ),
                DropdownButton<ProjectStatus?>(
                  value: _status,
                  isExpanded: true,
                  hint: const Text('All statuses'),
                  items: [
                    const DropdownMenuItem<ProjectStatus?>(
                      value: null,
                      child: Text('All statuses'),
                    ),
                    ...ProjectStatus.values.map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.label, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    _debounce?.cancel();
                    _status = value;
                    _load();
                  },
                ),
                DropdownButton<String>(
                  value: _sort,
                  isExpanded: true,
                  items: ['Latest', 'A-Z', 'Most progress', 'Completion date']
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    _debounce?.cancel();
                    _sort = value ?? _sort;
                    _load();
                  },
                ),
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Refresh projects',
                      onPressed: _loading ? null : () => _load(),
                      icon: const Icon(Icons.refresh),
                    ),
                    Text('$_total projects'),
                  ],
                ),
                if (_loading) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: () => _load(more: _ids.isNotEmpty),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                if (!_loading && _error == null && _ids.isEmpty)
                  const EmptyState(
                    icon: Icons.account_tree_outlined,
                    title: 'No matching projects',
                    message: 'Try a different search or status filter.',
                  ),
                const SizedBox(height: 12),
              ],
            );
          }
          if (index == _ids.length + 1) {
            return Center(
              child: TextButton(
                onPressed: _loading ? null : () => _load(more: true),
                child: const Text('Load more projects'),
              ),
            );
          }
          final project = controller.projectById(_ids[index - 1]);
          if (project == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ProjectCard(
              project: project,
              compact: true,
              onTap: () async {
                await widget.onOpen(project);
                if (mounted) _load();
              },
            ),
          );
        },
      ),
    );
  }
}
