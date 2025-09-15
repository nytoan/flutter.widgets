import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class TouchScrollView extends StatefulWidget {
  const TouchScrollView({
    required this.child,
    required this.controller,
    this.scrollDirection = Axis.vertical,
  });

  final Widget child;
  final ScrollController controller;
  final Axis scrollDirection;

  @override
  _TouchScrollViewState createState() => _TouchScrollViewState();
}

class _TouchScrollViewState extends State<TouchScrollView>
    with SingleTickerProviderStateMixin {
  late ScrollController _controller;

  late AnimationController _animationController;

  late DateTime _lastUpdateDate;

  bool _isInternalUpdate = false;

  bool _moved = false;

  bool _showDebug = false;

  Queue<(int, double)> _datas = Queue.from([
    (0, 0.0),
    (0, 0.0),
    (0, 0.0),
  ]);

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController.unbounded(vsync: this)
      ..addListener(_update)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          _animationController.stop();
        }
      });

    _controller = widget.controller;

    _controller.addListener(_onScrollControllerChange);
  }

  @override
  void didUpdateWidget(covariant TouchScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);

    _controller = widget.controller;
  }

  void _onScrollControllerChange() {
    if (!_isInternalUpdate && _animationController.isAnimating) {
      _animationController.stop();
    }
  }

  void _update() {
    if (_controller.hasClients) {
      _isInternalUpdate = true;
      _controller.jumpTo(
        min(
          max(
            _controller.position.minScrollExtent,
            _animationController.value,
          ),
          _controller.position.maxScrollExtent,
        ),
      );
      _isInternalUpdate = false;
    }
  }

  void _startInertiaScroll() {
    if (_moved) return;

    if (_showDebug) setState(() {});

    final d = _datas.fold((0, 0.0), (acc, n) {
      if (n.$1 > acc.$1) {
        acc = n;
      }
      return acc;
    });

    final velocity = d.$2 / (d.$1 / 1000);

    final simulation = FrictionSimulation(0.05, _controller.offset, -velocity);

    _animationController
      ..stop()
      ..animateWith(simulation);
  }

  void _dragDown() {
    if (!_controller.hasClients) return;

    _animationController.stop();

    _datas = Queue.from([
      (0, 0.0),
      (0, 0.0),
      (0, 0.0),
    ]);

    _moved = false;
  }

  void _dragStart() {
    _lastUpdateDate = DateTime.timestamp();
  }

  void _dragUpdate(double delta) {
    if (!_controller.hasClients) return;

    final timeStamp =
        DateTime.timestamp().difference(_lastUpdateDate).inMilliseconds;

    _lastUpdateDate = DateTime.timestamp();

    _controller.jumpTo(_controller.offset - delta);

    _datas
      ..removeFirst()
      ..addLast((timeStamp, delta));

    _moved = true;
  }

  void _dragEnd() {
    if (!_controller.hasClients ||
        _controller.offset < _controller.position.minScrollExtent ||
        _controller.offset > _controller.position.maxScrollExtent) {
      return;
    }

    _startInertiaScroll();
  }

  @override
  void dispose() {
    _controller.removeListener(_onScrollControllerChange);

    _animationController
      ..removeListener(_update)
      ..dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _debugView = _showDebug
        ? Container(
            decoration: BoxDecoration(
                color: Colors.red.shade200,
                border: Border.all(color: Colors.blue)),
            padding: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [Text('Debug:'), Text(_datas.toString())],
            ),
          )
        : SizedBox.shrink();
    return GestureDetector(
      onVerticalDragDown:
          widget.scrollDirection == Axis.vertical ? (_) => _dragDown() : null,
      onVerticalDragStart:
          widget.scrollDirection == Axis.vertical ? (_) => _dragStart() : null,
      onVerticalDragUpdate: widget.scrollDirection == Axis.vertical
          ? (details) => _dragUpdate(details.delta.dy)
          : null,
      onVerticalDragEnd:
          widget.scrollDirection == Axis.vertical ? (_) => _dragEnd() : null,
      onHorizontalDragDown:
          widget.scrollDirection == Axis.horizontal ? (_) => _dragDown() : null,
      onHorizontalDragStart: widget.scrollDirection == Axis.horizontal
          ? (_) => _dragStart()
          : null,
      onHorizontalDragUpdate: widget.scrollDirection == Axis.horizontal
          ? (details) => _dragUpdate(details.delta.dx)
          : null,
      onHorizontalDragEnd:
          widget.scrollDirection == Axis.horizontal ? (_) => _dragEnd() : null,
      child: Stack(
        children: [
          widget.child,
          _debugView,
        ],
      ),
    );
  }
}
