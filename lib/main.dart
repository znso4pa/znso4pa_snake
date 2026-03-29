import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:audioplayers/audioplayers.dart';

void main() => runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SnakeGame(),
    ));

class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key});

  @override
  _SnakeGameState createState() => _SnakeGameState();
}

class _SnakeGameState extends State<SnakeGame> with WidgetsBindingObserver {
  static const int columnCount = 20;
  
  bool _isShowingMenu = true;
  double _baseSpeed = 150.0;
  bool _accelerateOnEat = true;
  int _foodCountSetting = 1;
  List<int> _foods = [];
  bool _isMusicOn = true; // 新增：控制 BGM 开关

  List<int> snake = [45, 65, 85];
  var direction = 'down';
  final Queue<String> _directionQueue = Queue<String>();
  
  bool isPlaying = false;
  Timer? gameTimer;
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
    if (state == AppLifecycleState.paused) {
      gameTimer?.cancel();
      _audioPlayer.pause();
    }
  }

  // --- 新增：切换 BGM 开关的函数 ---
  void _toggleMusic() async {
    setState(() {
      _isMusicOn = !_isMusicOn;
    });
    if (_isMusicOn) {
      if (isPlaying) {
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
    setState(() {
      while (_foods.length < _foodCountSetting) {
        int newFood = Random().nextInt(totalSlots);
        if (!snake.contains(newFood) && !_foods.contains(newFood)) {
          _foods.add(newFood);
        }
      }
    });
  }

  void startGame() async {
    if (isPlaying) return;
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

    gameTimer = Timer.periodic(Duration(milliseconds: currentMs), (Timer timer) {
      updateSnake();
    });
  }

  void updateSnake() {
    if (!mounted) return;
    setState(() {
      if (_directionQueue.isNotEmpty) {
        direction = _directionQueue.removeFirst();
      }

      int currentHead = snake.last;
      int nextHead;

      switch (direction) {
        case 'down': nextHead = currentHead + columnCount; break;
        case 'up': nextHead = currentHead - columnCount; break;
        case 'left':
          nextHead = currentHead - 1;
          if (currentHead % columnCount == 0) { gameOver(); return; }
          break;
        case 'right':
          nextHead = currentHead + 1;
          if (currentHead % columnCount == columnCount - 1) { gameOver(); return; }
          break;
        default: nextHead = currentHead;
      }

      if (nextHead < 0 || nextHead >= totalSlots || snake.contains(nextHead)) {
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
    _audioPlayer.stop();
    if (currentScore > bestScore) bestScore = currentScore;
    setState(() {
      isPlaying = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.cyanAccent, width: 2), borderRadius: BorderRadius.circular(15)),
        title: const Center(
          child: Text("SYSTEM FAILURE", style: TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("SCORE: $currentScore", style: const TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 5),
            Text("BEST: $bestScore", style: const TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold)),
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
                child: const Text("RETRY", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 20),
              TextButton(
                onPressed: () { 
                  Navigator.pop(context); 
                  setState(() => _isShowingMenu = true); 
                },
                child: const Text("CONFIG", style: TextStyle(color: Colors.white30, fontSize: 12)),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _handleDirectionChange(String newDir) {
    String lastIntent = _directionQueue.isEmpty ? direction : _directionQueue.last;
    bool isOpposite = (newDir == 'up' && lastIntent == 'down') ||
                      (newDir == 'down' && lastIntent == 'up') ||
                      (newDir == 'left' && lastIntent == 'right') ||
                      (newDir == 'right' && lastIntent == 'left');
    if (!isOpposite && _directionQueue.length < 2) {
      _directionQueue.add(newDir);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    gameTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && !_isShowingMenu) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
            _handleDirectionChange('up');
          } else if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
            _handleDirectionChange('down');
          } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
            _handleDirectionChange('left');
          } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
            _handleDirectionChange('right');
          }
          return KeyEventResult.handled; 
        } else if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space && _isShowingMenu) {
          startGame();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1B5E20),
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
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
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: columnCount / rowCount,
                          child: GestureDetector(
                            onVerticalDragUpdate: (d) {
                              if (d.delta.dy > 5) _handleDirectionChange('down');
                              else if (d.delta.dy < -5) _handleDirectionChange('up');
                            },
                            onHorizontalDragUpdate: (d) {
                              if (d.delta.dx > 5) _handleDirectionChange('right');
                              else if (d.delta.dx < -5) _handleDirectionChange('left');
                            },
                            child: GridView.builder(
                              itemCount: totalSlots,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columnCount,
                              ),
                              itemBuilder: (context, i) {
                                final bool isSnakeHead = (i == snake.last);
                                final bool isSnakeBody = !isSnakeHead && snake.contains(i);
                                final bool isFood = _foods.contains(i);
                                
                                return Container(
                                  color: isSnakeHead 
                                      ? Colors.cyanAccent 
                                      : (isSnakeBody 
                                          ? Colors.white 
                                          : (isFood 
                                              ? Colors.redAccent 
                                              : ((i ~/ columnCount + i % columnCount) % 2 == 0 
                                                  ? const Color(0xFF2E7D32) 
                                                  : const Color(0xFF388E3C)))),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildControls(),
                  ],
                ),
                if (_isShowingMenu) _buildConfigMenu(),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildConfigMenu() {
    return Container(
      color: Colors.black.withOpacity(0.85),
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
              const Text("SETTING CONFIG", style: TextStyle(color: Colors.cyanAccent, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 20),
              _menuSlider("BASE SPEED", _baseSpeed, 50, 300, (v) => setState(() => _baseSpeed = v), suffix: "ms"),
              _menuSlider("FOOD COUNT", _foodCountSetting.toDouble(), 1, 8, (v) => setState(() => _foodCountSetting = v.toInt())),
              SwitchListTile(
                title: const Text("DYNAMIC ACCEL", style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text("+5ms/apple, max +20ms", style: TextStyle(color: Colors.cyanAccent, fontSize: 10)),
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
                child: const Text("INITIALIZE SYSTEM", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuSlider(String label, double val, double min, double max, Function(double) onChanged, {String suffix = ""}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$label: ${val.toInt()}$suffix", style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Slider(
          value: val, min: min, max: max,
          activeColor: Colors.cyanAccent,
          onChanged: onChanged,
        ),
      ],
    );
  }

  // --- 关键修改：增加静音图标到 Score Bar ---
  Widget _buildScoreBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("SCORE: $currentScore", style: const TextStyle(color: Colors.white, fontSize: 18)),
          Text("BEST: $bestScore", style: const TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(
            icon: Icon(
              _isMusicOn ? Icons.volume_up : Icons.volume_off,
              color: _isMusicOn ? Colors.cyanAccent : Colors.white24,
            ),
            onPressed: _toggleMusic,
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      child: isPlaying 
      ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBtn('left', Icons.keyboard_arrow_left),
            const SizedBox(width: 15),
            Column(
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
      : const SizedBox(height: 150), 
    );
  }

  Widget _buildBtn(String dir, IconData icon) {
    return GestureDetector(
      onTap: () => _handleDirectionChange(dir),
      child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 2),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: Colors.cyanAccent, size: 35),
      ),
    );
  }
}