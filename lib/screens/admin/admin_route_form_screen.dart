import 'package:flutter/material.dart';

import '../../models/place_model.dart';
import '../../models/route_config.dart';
import '../../services/place_repository.dart';
import '../../services/route_location_helper.dart';
import '../../services/route_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';

/// Add/edit form for an Admin-managed route leg.
///
/// Destinations come from the active Place catalog. From/To remain
/// editable because a route may contain transfer stops that are not tourist
/// destinations themselves (for example Birtamod or Jomsom), but existing
/// route locations are suggested and likely spelling duplicates are warned
/// about before saving.
class AdminRouteFormScreen extends StatefulWidget {
  final RouteConfig? route;
  final RouteRepository routeRepository;
  final PlaceRepository placeRepository;

  const AdminRouteFormScreen({
    super.key,
    this.route,
    required this.routeRepository,
    required this.placeRepository,
  });

  @override
  State<AdminRouteFormScreen> createState() => _AdminRouteFormScreenState();
}

class _AdminRouteFormScreenState extends State<AdminRouteFormScreen> {
  late final TextEditingController _fromController = TextEditingController(
    text: widget.route?.from ?? '',
  );

  late final TextEditingController _toController = TextEditingController(
    text: widget.route?.to ?? '',
  );

  late final TextEditingController _noteController = TextEditingController(
    text: widget.route?.note ?? '',
  );

  final FocusNode _fromFocusNode = FocusNode();
  final FocusNode _toFocusNode = FocusNode();

  late String? _destination = () {
    final value = widget.route?.destination.trim() ?? '';
    return value.isEmpty ? null : value;
  }();

  late final Set<String> _transportModes = Set<String>.from(
    widget.route?.transportModes ?? const <String>[],
  );

  late bool _bidirectional = widget.route?.bidirectional ?? true;

  List<Place> _places = const <Place>[];
  List<RouteConfig> _routes = const <RouteConfig>[];
  bool _loadingPlaces = true;
  bool _saving = false;
  String? _placesError;
  String? _formError;

  bool get _isEditing => widget.route != null;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _noteController.dispose();
    _fromFocusNode.dispose();
    _toFocusNode.dispose();
    super.dispose();
  }

  String _normalize(String value) => value.trim().toLowerCase();

  Future<void> _loadPlaces() async {
    setState(() {
      _loadingPlaces = true;
      _placesError = null;
    });

    try {
      final placesFuture = widget.placeRepository.getAllPlaces();
      final routesFuture = widget.routeRepository.getAllRoutes(
        includeInactive: true,
      );

      final places = await placesFuture;
      final routes = await routesFuture;

      if (!mounted) return;

      setState(() {
        _places = places;
        _routes = routes;
        _loadingPlaces = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingPlaces = false;
        _placesError = 'Could not load destinations.';
      });
    }
  }

  List<String> get _destinations {
    final values = <String, String>{};

    for (final place in _places) {
      final location = place.location.trim();

      if (location.isEmpty) continue;

      values.putIfAbsent(_normalize(location), () => location);
    }

    // Preserve the destination of an existing route even if all of its
    // catalog places are later deactivated.
    final current = _destination?.trim() ?? '';

    if (current.isNotEmpty) {
      values.putIfAbsent(_normalize(current), () => current);
    }

    final result = values.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return result;
  }

  List<String> get _knownLocations {
    final values = <String>[..._destinations];

    for (final route in _routes) {
      // When editing, do not let the record being edited make its own typo
      // look like an already-established canonical location.
      if (widget.route != null && route.id == widget.route!.id) {
        continue;
      }

      values
        ..add(route.destination)
        ..add(route.from)
        ..add(route.to);
    }

    return RouteLocationHelper.canonicalLocations(values);
  }

  void _toggleTransport(String mode, bool selected) {
    setState(() {
      if (selected) {
        _transportModes.add(mode);
      } else {
        _transportModes.remove(mode);
      }

      _formError = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    final destination = _destination?.trim() ?? '';
    var from = RouteLocationHelper.canonicalize(
      _fromController.text,
      _knownLocations,
    );
    var to = RouteLocationHelper.canonicalize(
      _toController.text,
      _knownLocations,
    );

    if (destination.isEmpty) {
      setState(() {
        _formError = 'Choose the final trip destination.';
      });
      return;
    }

    if (from.isEmpty || to.isEmpty) {
      setState(() {
        _formError = 'Enter both From and To locations.';
      });
      return;
    }

    final resolvedFrom = await _resolvePossibleTypo(label: 'From', value: from);

    if (resolvedFrom == null) return;

    from = resolvedFrom;

    final resolvedTo = await _resolvePossibleTypo(label: 'To', value: to);

    if (resolvedTo == null) return;

    to = resolvedTo;

    if (!mounted) return;

    _setControllerText(_fromController, from);
    _setControllerText(_toController, to);

    if (_normalize(from) == _normalize(to)) {
      setState(() {
        _formError = 'From and To must be different locations.';
      });
      return;
    }

    if (_transportModes.isEmpty) {
      setState(() {
        _formError = 'Choose at least one transportation mode.';
      });
      return;
    }

    final modes = _transportModes.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final route = RouteConfig(
      id: widget.route?.id ?? '',
      destination: destination,
      from: from,
      to: to,
      transportModes: modes,
      bidirectional: _bidirectional,
      note: _noteController.text.trim(),
      active: widget.route?.active ?? true,
    );

    setState(() {
      _saving = true;
      _formError = null;
    });

    try {
      if (_isEditing) {
        await widget.routeRepository.updateRoute(route);
      } else {
        await widget.routeRepository.createRoute(route);
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _formError = 'Could not save route. $error';
      });
    }
  }

  Future<String?> _resolvePossibleTypo({
    required String label,
    required String value,
  }) async {
    final suggestion = RouteLocationHelper.nearDuplicate(
      value,
      _knownLocations,
    );

    if (suggestion == null) {
      return value;
    }

    final useSuggestion = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Possible location typo'),
          content: Text(
            '$label location "$value" is very close to the existing '
            'location "$suggestion".\n\n'
            'Using the same spelling keeps route legs connected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Keep "$value"'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('Use "$suggestion"'),
            ),
          ],
        );
      },
    );

    if (!mounted || useSuggestion == null) {
      return null;
    }

    return useSuggestion ? suggestion : value;
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) return;

    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Widget _locationField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsViewOpenDirection: OptionsViewOpenDirection.down,
      optionsBuilder: (textEditingValue) {
        return RouteLocationHelper.suggestions(
          textEditingValue.text,
          _knownLocations,
        );
      },
      displayStringForOption: (option) => option,
      onSelected: (option) {
        _setControllerText(controller, option);

        if (_formError != null) {
          setState(() => _formError = null);
        }
      },
      fieldViewBuilder:
          (context, fieldController, fieldFocusNode, onFieldSubmitted) {
            return TextField(
              controller: fieldController,
              focusNode: fieldFocusNode,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) {
                if (_formError != null) {
                  setState(() => _formError = null);
                }
              },
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                prefixIcon: Icon(icon),
                suffixIcon: const Icon(Icons.arrow_drop_down),
                border: const OutlineInputBorder(),
              ),
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        final optionList = options.toList();

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width - (AppSpacing.screen * 2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: optionList.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final option = optionList[index];

                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined),
                      title: Text(option),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit route' : 'Add route')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text('Planner route', style: AppType.bodyEmphasis),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Create one travel leg at a time. Multi-stop trips can use '
              'several legs for the same final destination.',
              style: AppType.caption,
            ),
            const SizedBox(height: AppSpacing.lg),

            if (_loadingPlaces)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: LinearProgressIndicator(),
              )
            else if (_placesError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_placesError!),
                    TextButton.icon(
                      onPressed: _loadPlaces,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: DropdownButtonFormField<String>(
                  initialValue: destinations.contains(_destination)
                      ? _destination
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Final destination',
                    hintText: 'Choose destination',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final destination in destinations)
                      DropdownMenuItem<String>(
                        value: destination,
                        child: Text(destination),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _destination = value;
                      _formError = null;
                    });
                  },
                ),
              ),

            _locationField(
              controller: _fromController,
              focusNode: _fromFocusNode,
              label: 'From',
              hint: 'Type or choose a location',
              icon: Icons.trip_origin,
            ),
            const SizedBox(height: AppSpacing.md),

            _locationField(
              controller: _toController,
              focusNode: _toFocusNode,
              label: 'To',
              hint: 'Type or choose a location',
              icon: Icons.location_on_outlined,
            ),

            const SizedBox(height: AppSpacing.xl),

            Text('Transportation', style: AppType.bodyEmphasis),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Select every mode that can reasonably be used on this leg.',
              style: AppType.caption,
            ),
            const SizedBox(height: AppSpacing.sm),

            YatraCard(
              child: Column(
                children: [
                  for (final mode in kRouteTransportModes)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(mode),
                      value: _transportModes.contains(mode),
                      onChanged: (value) {
                        _toggleTransport(mode, value ?? false);
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bidirectional route'),
              subtitle: Text(
                _bidirectional
                    ? 'The same leg can also be travelled in reverse.'
                    : 'This leg works only from From → To.',
              ),
              value: _bidirectional,
              onChanged: (value) {
                setState(() {
                  _bidirectional = value;
                });
              },
            ),

            const SizedBox(height: AppSpacing.md),

            TextField(
              controller: _noteController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Route note (optional)',
                hintText: 'e.g. Road may be difficult during monsoon.',
                border: OutlineInputBorder(),
              ),
            ),

            if (_formError != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _formError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            YatraPrimaryButton(
              label: _isEditing ? 'Save changes' : 'Add route',
              icon: Icons.check,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
