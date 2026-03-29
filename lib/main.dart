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
  List<int> snake = [45, 65, 85];
  int food = 150;
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

  void generateNewFood() {
    if (totalSlots == 0) return;
    int newFood = Random().nextInt(totalSlots);
    if (snake.contains(newFood)) {
      generateNewFood();
    } else {
      setState(() => food = newFood);
    }
  }

  void startGame() async {
    if (isPlaying) return;
    _directionQueue.clear(); 
    _focusNode.requestFocus(); 
    
    try {
      await _audioPlayer.play(AssetSource('bgm.mp3'));
    } catch (e) {
      debugPrint("BGM Error: $e");
    }

    setState(() {
      isPlaying = true;
      snake = [45, 65, 85];
      direction = 'down';
      currentScore = 0;
    });
    
    gameTimer = Timer.periodic(const Duration(milliseconds: 120), (Timer timer) {
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
      if (nextHead == food) {
        currentScore++;
        generateNewFood();
      } else {
        snake.removeAt(0);
      }
    });
  }

  void gameOver() {
    gameTimer?.cancel();
    _audioPlayer.stop();
    if (currentScore > bestScore) bestScore = currentScore;
    setState(() => isPlaying = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.cyanAccent, width: 1)),
        title: const Center(child: Text("FAIL", style: TextStyle(color: Colors.redAccent, fontSize: 32, fontWeight: FontWeight.bold))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("SCORE: $currentScore", style: const TextStyle(color: Colors.white)),
            Text("BEST: $bestScore", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () { 
                Navigator.pop(context); 
                startGame(); 
              },
              child: const Text("RETRY", style: TextStyle(color: Colors.cyanAccent)),
            ),
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
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
            _handleDirectionChange('up');
          } else if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
            _handleDirectionChange('down');
          } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
            _handleDirectionChange('left');
          } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
            _handleDirectionChange('right');
          } else if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter) {
            if (!isPlaying) startGame();
          }
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

            return Column(
              children: [
                _buildScoreBar(),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: columnCount / rowCount,
                      child: RepaintBoundary(
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
                              final bool isFood = (i == food);
                              
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
                ),
                _buildControls(),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildScoreBar() {
    return SizedBox(
      height: 50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text("SCORE: $currentScore", style: const TextStyle(color: Colors.white, fontSize: 20)),
          Text("BEST: $bestScore", style: const TextStyle(color: Colors.cyanAccent, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: isPlaying 
      ? Column(
          children: [
            _buildBtn('up', Icons.keyboard_arrow_up),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBtn('left', Icons.keyboard_arrow_left),
                const SizedBox(width: 50),
                _buildBtn('right', Icons.keyboard_arrow_right),
              ],
            ),
            const SizedBox(height: 5),
            _buildBtn('down', Icons.keyboard_arrow_down),
          ],
        )
      : ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
          onPressed: startGame,
          child: const Text("INITIALIZE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
    );
  }

  Widget _buildBtn(String dir, IconData icon) {
    return GestureDetector(
      onTap: () => _handleDirectionChange(dir),
      child: Container(
        width: 55, height: 55,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.cyanAccent, size: 30),
      ),
    );
  }
}