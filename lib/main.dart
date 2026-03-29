import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

void main() => runApp(
  const MaterialApp(debugShowCheckedModeBanner: false, home: SnakeGame()),
);

class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key});

  @override
  _SnakeGameState createState() => _SnakeGameState();
}

class _SnakeGameState extends State<SnakeGame> with WidgetsBindingObserver {
  static const int columnCount = 20;

  bool _isShowingMenu = true;
  bool _isPaused = false;
  bool _isCountingDown = false;
  int _countdownValue = 3;
  double _baseSpeed = 150.0;
  bool _accelerateOnEat = true;
  int _foodCountSetting = 1;
  List<int> _foods = [];
  bool _isMusicOn = true;

  List<int> snake = [45, 65, 85];
  var direction = 'down';
  final Queue<String> _directionQueue = Queue<String>();

  bool isPlaying = false;
  Timer? gameTimer;
  Timer? _countdownTimer;
  int totalSlots = 0;
  int rowCount = 0;
  int currentScore = 0;
  int bestScore = 0;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        isPlaying &&
        !_isPaused &&
        !_isCountingDown) {
      _togglePause();
    }
  }

  void _togglePause() {
    _focusNode.requestFocus();
    if (!isPlaying || _isCountingDown) return;
    if (!_isPaused) {
      setState(() => _isPaused = true);
      gameTimer?.cancel();
      _audioPlayer.pause();
    } else {
      _startResumeCountdown();
    }
  }

  void _startResumeCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _isPaused = false;
      _isCountingDown = true;
      _countdownValue = 3;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdownValue > 1) {
          _countdownValue--;
        } else {
          timer.cancel();
          _countdownTimer = null;
          _isCountingDown = false;
          _startTimer();
          if (_isMusicOn) _audioPlayer.resume();
        }
      });
    });
  }

  void _toggleMusic() async {
    setState(() => _isMusicOn = !_isMusicOn);
    if (_isMusicOn) {
      if (isPlaying && !_isPaused && !_isCountingDown) {
        try {
          await _audioPlayer.resume();
        } catch (e) {
          await _audioPlayer.play(AssetSource('bgm.mp3'));
        }
      }
    } else {
      await _audioPlayer.pause();
    }
  }

  void generateNewFood() {
    if (totalSlots == 0) return;
    List<int> availableSlots = [];
    for (int i = 0; i < totalSlots; i++) {
      if (!snake.contains(i) && !_foods.contains(i)) availableSlots.add(i);
    }
    if (availableSlots.isEmpty) return;
    setState(() {
      while (_foods.length < _foodCountSetting && availableSlots.isNotEmpty) {
        int randomIndex = Random().nextInt(availableSlots.length);
        _foods.add(availableSlots.removeAt(randomIndex));
      }
    });
  }

  void startGame() async {
    if (isPlaying) return;
    _countdownTimer?.cancel();
    _directionQueue.clear();
    _focusNode.requestFocus();
    _foods.clear();
    if (_isMusicOn) {
      try {
        await _audioPlayer.play(AssetSource('bgm.mp3'));
      } catch (e) {
        debugPrint("BGM Error: $e");
      }
    }
    setState(() {
      _isShowingMenu = false;
      _isPaused = false;
      _isCountingDown = false;
      isPlaying = true;
      snake = [45, 65, 85];
      direction = 'down';
      currentScore = 0;
      generateNewFood();
    });
    _startTimer();
  }

  void _startTimer() {
    gameTimer?.cancel();
    int acceleration = min(currentScore * 5, 20);
    int currentMs = _accelerateOnEat
        ? max(40, _baseSpeed.toInt() - acceleration)
        : _baseSpeed.toInt();
    gameTimer = Timer.periodic(Duration(milliseconds: currentMs), (
      Timer timer,
    ) {
      updateSnake();
    });
  }

  void updateSnake() {
    if (!mounted || _isPaused || _isCountingDown) return;
    setState(() {
      if (_directionQueue.isNotEmpty) direction = _directionQueue.removeFirst();
      int currentHead = snake.last;
      int curX = currentHead % columnCount;
      int curY = currentHead ~/ columnCount;
      int nextX = curX, nextY = curY;
      switch (direction) {
        case 'down':
          nextY++;
          break;
        case 'up':
          nextY--;
          break;
        case 'left':
          nextX--;
          break;
        case 'right':
          nextX++;
          break;
      }
      if (nextX < 0 || nextX >= columnCount || nextY < 0 || nextY >= rowCount) {
        gameOver();
        return;
      }
      int nextHead = nextY * columnCount + nextX;
      if (snake.contains(nextHead)) {
        gameOver();
        return;
      }
      snake.add(nextHead);
      if (_foods.contains(nextHead)) {
        _foods.remove(nextHead);
        currentScore++;
        generateNewFood();
        if (_accelerateOnEat) _startTimer();
      } else {
        snake.removeAt(0);
      }
    });
  }

  void gameOver() {
    gameTimer?.cancel();
    _countdownTimer?.cancel();
    _audioPlayer.stop();
    if (currentScore > bestScore) bestScore = currentScore;
    setState(() => isPlaying = false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.cyanAccent, width: 2),
          borderRadius: BorderRadius.circular(15),
        ),
        title: const Center(
          child: Text(
            "SYSTEM FAILURE",
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "SCORE: $currentScore",
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 5),
            Text(
              "BEST: $bestScore",
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  startGame();
                },
                child: const Text(
                  "RETRY",
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _isShowingMenu = true);
                },
                child: const Text(
                  "CONFIG",
                  style: TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleDirectionChange(String newDir) {
    if (_isPaused || _isCountingDown || !isPlaying) return;
    String lastIntent = _directionQueue.isEmpty
        ? direction
        : _directionQueue.last;
    bool isOpposite =
        (newDir == 'up' && lastIntent == 'down') ||
        (newDir == 'down' && lastIntent == 'up') ||
        (newDir == 'left' && lastIntent == 'right') ||
        (newDir == 'right' && lastIntent == 'left');
    if (!isOpposite && _directionQueue.length < 2) _directionQueue.add(newDir);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    gameTimer?.cancel();
    _countdownTimer?.cancel();
    _audioPlayer.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: SafeArea(
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              final key = event.logicalKey;
              if (key == LogicalKeyboardKey.space) {
                if (_isShowingMenu)
                  startGame();
                else
                  _togglePause();
                return KeyEventResult.handled;
              }
              if (!_isShowingMenu &&
                  !_isPaused &&
                  !_isCountingDown &&
                  isPlaying) {
                if (key == LogicalKeyboardKey.arrowUp ||
                    key == LogicalKeyboardKey.keyW)
                  _handleDirectionChange('up');
                else if (key == LogicalKeyboardKey.arrowDown ||
                    key == LogicalKeyboardKey.keyS)
                  _handleDirectionChange('down');
                else if (key == LogicalKeyboardKey.arrowLeft ||
                    key == LogicalKeyboardKey.keyA)
                  _handleDirectionChange('left');
                else if (key == LogicalKeyboardKey.arrowRight ||
                    key == LogicalKeyboardKey.keyD)
                  _handleDirectionChange('right');
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              double cellSize = constraints.maxWidth / columnCount;
              double playAreaHeight = constraints.maxHeight - 240;
              rowCount = (playAreaHeight / cellSize).floor();
              totalSlots = columnCount * rowCount;

              return Stack(
                children: [
                  Column(
                    children: [
                      _buildScoreBar(),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (details) {
                            if (details.delta.dy > 8)
                              _handleDirectionChange('down');
                            else if (details.delta.dy < -8)
                              _handleDirectionChange('up');
                          },
                          onHorizontalDragUpdate: (details) {
                            if (details.delta.dx > 8)
                              _handleDirectionChange('right');
                            else if (details.delta.dx < -8)
                              _handleDirectionChange('left');
                          },
                          child: Center(
                            child: Container(
                              width: constraints.maxWidth,
                              height: rowCount * cellSize,
                              color: const Color(0xFF2E7D32),
                              child: CustomPaint(
                                painter: SnakePainter(
                                  snake: List.from(snake),
                                  foods: List.from(_foods),
                                  columnCount: columnCount,
                                  rowCount: rowCount,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildControls(),
                    ],
                  ),
                  if (_isPaused || _isCountingDown)
                    Column(
                      children: [
                        const SizedBox(height: 60),
                        Expanded(
                          child: Container(
                            color: _isPaused
                                ? Colors.black54
                                : Colors.transparent,
                            child: Center(
                              child: Text(
                                _isPaused ? "PAUSED" : "$_countdownValue",
                                style: TextStyle(
                                  color: _isPaused
                                      ? Colors.white
                                      : Colors.cyanAccent,
                                  fontSize: _isPaused ? 32 : 80,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: _isPaused ? 4 : 0,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 180),
                      ],
                    ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildScoreBar(),
                  ),
                  if (_isShowingMenu) _buildConfigMenu(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildConfigMenu() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            border: Border.all(color: Colors.cyanAccent, width: 2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "SETTING CONFIG",
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              _menuSlider(
                "BASE SPEED",
                _baseSpeed,
                50,
                300,
                (v) => setState(() => _baseSpeed = v),
                suffix: "ms",
              ),
              _menuSlider(
                "FOOD COUNT",
                _foodCountSetting.toDouble(),
                1,
                8,
                (v) => setState(() => _foodCountSetting = v.toInt()),
              ),
              SwitchListTile(
                title: const Text(
                  "DYNAMIC ACCEL",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  "+5ms speed per food (max 20ms)",
                  style: TextStyle(color: Colors.white24, fontSize: 10),
                ),
                value: _accelerateOnEat,
                activeColor: Colors.cyanAccent,
                onChanged: (v) => setState(() => _accelerateOnEat = v),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  minimumSize: const Size(double.infinity, 45),
                ),
                onPressed: startGame,
                child: const Text(
                  "INITIALIZE SYSTEM",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuSlider(
    String label,
    double val,
    double min,
    double max,
    Function(double) onChanged, {
    String suffix = "",
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$label: ${val.toInt()}$suffix",
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Slider(
          value: val,
          min: min,
          max: max,
          activeColor: Colors.cyanAccent,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildScoreBar() {
    return Container(
      height: 60,
      color: const Color(0xFF1B5E20),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "SCORE: $currentScore",
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  (_isPaused || _isCountingDown)
                      ? Icons.play_arrow
                      : Icons.pause,
                  color: Colors.white,
                ),
                onPressed: _togglePause,
              ),
              IconButton(
                icon: Icon(
                  _isMusicOn ? Icons.volume_up : Icons.volume_off,
                  color: _isMusicOn ? Colors.cyanAccent : Colors.white24,
                ),
                onPressed: _toggleMusic,
              ),
            ],
          ),
          Text(
            "BEST: $bestScore",
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      height: 180,
      padding: const EdgeInsets.only(bottom: 20),
      child: isPlaying
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBtn('left', Icons.keyboard_arrow_left),
                const SizedBox(width: 15),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBtn('up', Icons.keyboard_arrow_up),
                    const SizedBox(height: 15),
                    _buildBtn('down', Icons.keyboard_arrow_down),
                  ],
                ),
                const SizedBox(width: 15),
                _buildBtn('right', Icons.keyboard_arrow_right),
              ],
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildBtn(String dir, IconData icon) {
    return GestureDetector(
      onTap: () => _handleDirectionChange(dir),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          border: Border.all(
            color: Colors.cyanAccent.withOpacity(0.5),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: Colors.cyanAccent, size: 35),
      ),
    );
  }
}

class SnakePainter extends CustomPainter {
  final List<int> snake;
  final List<int> foods;
  final int columnCount;
  final int rowCount;

  SnakePainter({
    required this.snake,
    required this.foods,
    required this.columnCount,
    required this.rowCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cellW = size.width / columnCount;
    final double cellH = size.height / rowCount;
    final bgPaint = Paint()..color = const Color(0xFF388E3C);
    for (int i = 0; i < columnCount * rowCount; i++) {
      if ((i ~/ columnCount + i % columnCount) % 2 == 1) {
        canvas.drawRect(
          Rect.fromLTWH(
            (i % columnCount) * cellW,
            (i ~/ columnCount) * cellH,
            cellW,
            cellH,
          ),
          bgPaint,
        );
      }
    }
    final bodyPaint = Paint()..color = Colors.white;
    final headPaint = Paint()..color = Colors.cyanAccent;
    for (int i = 0; i < snake.length; i++) {
      final rect = Rect.fromLTWH(
        (snake[i] % columnCount) * cellW,
        (snake[i] ~/ columnCount) * cellH,
        cellW,
        cellH,
      );
      canvas.drawRect(
        rect.inflate(-0.5),
        i == snake.length - 1 ? headPaint : bodyPaint,
      );
    }
    final foodPaint = Paint()..color = Colors.redAccent;
    for (var food in foods) {
      final rect = Rect.fromLTWH(
        (food % columnCount) * cellW,
        (food ~/ columnCount) * cellH,
        cellW,
        cellH,
      );
      canvas.drawOval(rect.inflate(-2), foodPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SnakePainter oldDelegate) => true;
}
