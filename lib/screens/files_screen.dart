import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../nav.dart';
import '../services/connector.dart';
import '../services/remote_fs.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

String formatSize(int? bytes) {
  if (bytes == null) {
    return '';
  }
  if (bytes < 1024) {
    return '$bytes B';
  }
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unit]}';
}

String formatDate(DateTime? date) {
  if (date == null) {
    return '';
  }
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} ${two(date.hour)}:${two(date.minute)}';
}

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key, required this.host});

  final Host host;

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  late final RemoteFs _fs = RemoteFs.forHost(widget.host);
  String _path = '/';
  List<RemoteEntry> _entries = [];
  bool _connecting = true;
  bool _connected = false;
  String? _connectError;
  String? _busyLabel;
  bool _showHidden = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    unawaited(_fs.close());
    super.dispose();
  }

  Future<void> _connect() async {
    if (_connected) {
      await _fs.close();
      _connected = false;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _connecting = true;
      _connectError = null;
    });
    try {
      final home = await _fs.connect();
      _connected = true;
      if (!mounted) {
        return;
      }
      final entries = await _fs.list(home);
      if (!mounted) {
        return;
      }
      setState(() {
        _path = home;
        _entries = entries;
        _connecting = false;
      });
    } catch (e) {
      await _fs.close();
      _connected = false;
      if (!mounted) {
        return;
      }
      setState(() {
        _connecting = false;
        _connectError = describeSshError(e);
      });
    }
  }

  Future<void> _open(String path) async {
    try {
      final entries = await _fs.list(path);
      if (!mounted) {
        return;
      }
      setState(() {
        _path = path;
        _entries = entries;
      });
    } catch (e) {
      showSnack(describeSshError(e), error: true);
    }
  }

  Future<void> _refresh() => _open(_path);

  Future<void> _withBusy(String label, Future<void> Function() action) async {
    if (_busyLabel != null) {
      return;
    }
    setState(() => _busyLabel = label);
    try {
      await action();
    } catch (e) {
      showSnack(describeSshError(e), error: true);
    } finally {
      if (mounted) {
        setState(() => _busyLabel = null);
      }
    }
  }

  Future<void> _tapEntry(RemoteEntry entry) async {
    if (entry.isDir) {
      await _open(entry.path);
      return;
    }
    if (entry.isLink) {
      try {
        final entries = await _fs.list(entry.path);
        if (!mounted) {
          return;
        }
        setState(() {
          _path = entry.path;
          _entries = entries;
        });
        return;
      } catch (_) {
        if (!mounted) {
          return;
        }
      }
    }
    await _download(entry);
  }

  Future<File> _uniqueFile(Directory dir, String name) async {
    var file = File('${dir.path}${Platform.pathSeparator}$name');
    if (!await file.exists()) {
      return file;
    }
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    var counter = 1;
    while (await file.exists()) {
      file = File('${dir.path}${Platform.pathSeparator}$base ($counter)$ext');
      counter++;
    }
    return file;
  }

  Future<void> _fetch(String remotePath, File target) async {
    await target.parent.create(recursive: true);
    await _fs.download(remotePath, target);
  }

  Future<void> _download(RemoteEntry entry) async {
    await _withBusy('files.downloading'.tr(namedArgs: {'name': entry.name}), () async {
      Directory? dir;
      try {
        dir = await getDownloadsDirectory();
      } catch (_) {
        dir = null;
      }
      dir ??= await getApplicationDocumentsDirectory();
      final file = await _uniqueFile(dir, entry.name);
      await _fetch(entry.path, file);
      showSnack('files.saved'.tr(namedArgs: {'path': file.path}));
    });
  }

  Future<void> _share(RemoteEntry entry) async {
    await _withBusy('files.preparing'.tr(namedArgs: {'name': entry.name}), () async {
      final temp = await getTemporaryDirectory();
      final dir = Directory('${temp.path}${Platform.pathSeparator}shellbox_share');
      await dir.create(recursive: true);
      final file = File('${dir.path}${Platform.pathSeparator}${entry.name}');
      if (await file.exists()) {
        await file.delete();
      }
      await _fetch(entry.path, file);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    });
  }

  Future<void> _rename(RemoteEntry entry) async {
    final name = await promptText(title: 'keys.rename'.tr(), label: 'files.new_name'.tr(), initial: entry.name, mono: true);
    if (name == null || name == entry.name || !mounted) {
      return;
    }
    if (name.contains('/')) {
      showSnack('files.no_slash'.tr(), error: true);
      return;
    }
    await _withBusy('files.renaming'.tr(), () async {
      await _fs.rename(entry.path, joinRemote(parentRemote(entry.path), name));
      await _refresh();
    });
  }

  Future<void> _removeRecursive(String path) async {
    final children = await _fs.list(path);
    for (final child in children) {
      if (child.isDir && !child.isLink) {
        await _removeRecursive(child.path);
      } else {
        await _fs.removeFile(child.path);
      }
    }
    await _fs.removeEmptyDir(path);
  }

  Future<void> _delete(RemoteEntry entry) async {
    final ok = await confirmAction(
      title: entry.isDir ? 'files.delete_folder_title'.tr() : 'files.delete_file_title'.tr(),
      message: entry.isDir
          ? 'files.delete_folder_msg'.tr(namedArgs: {'name': entry.name})
          : 'files.delete_file_msg'.tr(namedArgs: {'name': entry.name}),
    );
    if (!ok || !mounted) {
      return;
    }
    await _withBusy('files.deleting'.tr(), () async {
      if (entry.isDir && !entry.isLink) {
        await _removeRecursive(entry.path);
      } else {
        await _fs.removeFile(entry.path);
      }
      await _refresh();
      showSnack('files.deleted'.tr(namedArgs: {'name': entry.name}));
    });
  }

  Future<void> _upload() async {
    final List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles(dialogTitle: 'files.pick_upload'.tr());
    } catch (e) {
      showSnack('files.pick_failed'.tr(namedArgs: {'error': '$e'}), error: true);
      return;
    }
    if (!mounted || files.isEmpty) {
      return;
    }
    final targetDir = _path;
    await _withBusy('files.uploading'.tr(), () async {
      var index = 0;
      for (final file in files) {
        index++;
        if (mounted) {
          setState(() => _busyLabel =
              'files.uploading_file'.tr(namedArgs: {'name': file.name, 'index': '$index', 'total': '${files.length}'}));
        }
        await _fs.upload(file, joinRemote(targetDir, file.name));
      }
      if (mounted && _path == targetDir) {
        await _refresh();
      }
      showSnack(files.length == 1
          ? 'files.uploaded_one'.tr()
          : 'files.uploaded_many'.tr(namedArgs: {'count': '${files.length}'}));
    });
  }

  Future<void> _newFolder() async {
    final name = await promptText(title: 'files.new_folder'.tr(), label: 'files.folder_name'.tr(), confirmLabel: 'keys.create'.tr(), mono: true);
    if (name == null || !mounted) {
      return;
    }
    if (name.contains('/')) {
      showSnack('files.no_slash'.tr(), error: true);
      return;
    }
    await _withBusy('files.creating_folder'.tr(), () async {
      await _fs.mkdir(joinRemote(_path, name));
      await _refresh();
    });
  }

  Future<void> _entryMenu(RemoteEntry entry) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetTitle(entry.name, subtitle: entry.path),
            if (entry.isDir || entry.isLink)
              ListTile(
                leading: const Icon(HugeIcons.strokeRoundedFolderOpen),
                title: Text('files.open'.tr()),
                onTap: () => Navigator.of(sheetContext).pop('open'),
              ),
            if (!entry.isDir) ...[
              ListTile(
                leading: const Icon(HugeIcons.strokeRoundedDownload04),
                title: Text('files.download'.tr()),
                onTap: () => Navigator.of(sheetContext).pop('download'),
              ),
              ListTile(
                leading: const Icon(HugeIcons.strokeRoundedShare08),
                title: Text('files.share'.tr()),
                onTap: () => Navigator.of(sheetContext).pop('share'),
              ),
            ],
            ListTile(
              leading: const Icon(HugeIcons.strokeRoundedFileEdit),
              title: Text('keys.rename'.tr()),
              onTap: () => Navigator.of(sheetContext).pop('rename'),
            ),
            ListTile(
              leading: Icon(HugeIcons.strokeRoundedDelete02, color: AppColors.red),
              title: Text('common.delete'.tr(), style: TextStyle(color: AppColors.red)),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case 'open':
        await _tapEntry(entry);
      case 'download':
        await _download(entry);
      case 'share':
        await _share(entry);
      case 'rename':
        await _rename(entry);
      case 'delete':
        await _delete(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = !_connecting && _connectError == null;
    return PopScope(
      canPop: !ready || _path == '/',
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _open(parentRemote(_path));
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_fs.kind),
              Text(
                widget.host.subtitle,
                style: AppFonts.monoStyle(size: 12, color: AppColors.textDim),
              ),
            ],
          ),
          actions: [
            if (ready) ...[
              IconButton(
                tooltip: _showHidden ? 'files.hide_hidden'.tr() : 'files.show_hidden'.tr(),
                icon: Icon(_showHidden ? HugeIcons.strokeRoundedView : HugeIcons.strokeRoundedViewOffSlash),
                onPressed: () => setState(() => _showHidden = !_showHidden),
              ),
              IconButton(
                tooltip: 'files.new_folder'.tr(),
                icon: const Icon(HugeIcons.strokeRoundedFolderAdd),
                onPressed: _busyLabel == null ? _newFolder : null,
              ),
            ],
          ],
          bottom: ready ? PreferredSize(preferredSize: const Size.fromHeight(44), child: _buildBreadcrumbs()) : null,
        ),
        floatingActionButton: ready
            ? FloatingActionButton.extended(
                heroTag: 'sftp-fab',
                onPressed: _busyLabel == null ? _upload : null,
                icon: const Icon(HugeIcons.strokeRoundedUpload04),
                label: Text('files.upload'.tr()),
              )
            : null,
        body: Column(
          children: [
            if (_busyLabel != null)
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_busyLabel!, style: TextStyle(color: AppColors.textDim, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                ),
              ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    final parts = _path.split('/').where((p) => p.isNotEmpty).toList();
    final crumbs = <MapEntry<String, String>>[const MapEntry('/', '/')];
    var current = '';
    for (final part in parts) {
      current = '$current/$part';
      crumbs.add(MapEntry(part, current));
    }
    return Container(
      height: 44,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth > 24 ? constraints.maxWidth - 24 : 0),
            child: Row(
              children: [
                for (var i = 0; i < crumbs.length; i++) ...[
                  if (i > 0) Icon(HugeIcons.strokeRoundedArrowRight01, size: 18, color: AppColors.textDim),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: i == crumbs.length - 1 ? null : () => _open(crumbs[i].value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: Text(
                        crumbs[i].key,
                        style: AppFonts.monoStyle(
                          size: 13,
                          color: i == crumbs.length - 1 ? AppColors.text : AppColors.accent,
                          weight: i == crumbs.length - 1 ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_connecting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('files.connecting'.tr(namedArgs: {'host': widget.host.title}), style: TextStyle(color: AppColors.textDim)),
          ],
        ),
      );
    }
    final error = _connectError;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GradientIcon(icon: HugeIcons.strokeRoundedWifiDisconnected01, color: AppColors.red, size: 64),
              const SizedBox(height: 18),
              Text('files.connect_failed'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              const SizedBox(height: 8),
              Text(error, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDim)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _connect,
                icon: const Icon(HugeIcons.strokeRoundedRefresh),
                label: Text('files.retry'.tr()),
              ),
            ],
          ),
        ),
      );
    }
    final visible = _showHidden ? _entries : _entries.where((e) => !e.hidden).toList();
    final hasParent = _path != '/';
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: visible.length + (hasParent ? 1 : 0) + (visible.isEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          if (hasParent && index == 0) {
            return ListTile(
              leading: _FileIcon(icon: HugeIcons.strokeRoundedFolderUpload, color: AppColors.textDim),
              title: Text('..', style: AppFonts.monoStyle(size: 14)),
              subtitle: Text('files.up'.tr(), style: TextStyle(color: AppColors.textDim, fontSize: 12)),
              onTap: () => _open(parentRemote(_path)),
            );
          }
          final itemIndex = index - (hasParent ? 1 : 0);
          if (itemIndex >= visible.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(
                child: Text('files.folder_empty'.tr(), style: TextStyle(color: AppColors.textDim)),
              ),
            );
          }
          final entry = visible[itemIndex];
          final details = <String>[
            if (!entry.isDir && entry.size != null) formatSize(entry.size),
            if (entry.modified != null) formatDate(entry.modified),
          ].join(' · ');
          return ListTile(
            leading: _FileIcon(
              icon: entry.isDir
                  ? HugeIcons.strokeRoundedFolder01
                  : (entry.isLink ? HugeIcons.strokeRoundedLink01 : HugeIcons.strokeRoundedFile01),
              color: entry.isDir ? AppColors.accent : (entry.isLink ? AppColors.yellow : AppColors.textDim),
            ),
            title: Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.monoStyle(
                size: 14,
                color: entry.hidden ? AppColors.textDim : AppColors.text,
                weight: entry.isDir ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            subtitle: Text(
              entry.permissions.isEmpty ? details : '${entry.permissions}  $details',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.monoStyle(size: 11, color: AppColors.textDim),
            ),
            trailing: IconButton(
              icon: Icon(HugeIcons.strokeRoundedMoreVerticalCircle01, color: AppColors.textDim),
              onPressed: _busyLabel == null ? () => _entryMenu(entry) : null,
            ),
            onTap: _busyLabel == null ? () => _tapEntry(entry) : null,
            onLongPress: _busyLabel == null ? () => _entryMenu(entry) : null,
          );
        },
      ),
    );
  }
}

class _FileIcon extends StatelessWidget {
  const _FileIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
