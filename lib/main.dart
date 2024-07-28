import 'dart:io';

import 'package:cindy/pages/index.dart' show ChatScreen;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';

const String _apiKey = String.fromEnvironment('API_KEY');

void main() {
  runApp(const GenerativeAISample());
}

class GenerativeAISample extends StatelessWidget {
  const GenerativeAISample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter + Generative AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color.fromARGB(255, 171, 222, 244),
        ),
        useMaterial3: true,
      ),
      home: const ChatScreen(
        title: 'Detector de biodiversidad',
        apiKey: "",
      ),
    );
  }
}



class MessageWidget extends StatelessWidget {
  const MessageWidget({
    super.key,
    this.image,
    this.text,
    required this.isFromUser,
  });

  final Image? image;
  final String? text;
  final bool isFromUser;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            decoration: BoxDecoration(
              color: isFromUser
                  ? Colors.pink
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 15,
              horizontal: 20,
            ),
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                if (text case final text?) MarkdownBody(data: text),
                if (image case final image?) image,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

typedef _Message = ({Image? image, String? text, bool fromUser});

class ChatWidget extends StatefulWidget {
  const ChatWidget({
    required this.apiKey,
    super.key,
  });

  final String apiKey;

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  late final GenerativeModel _model;
  late final ChatSession _chat;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode();

  final List<_Message> _messages = [];
  bool _loading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: widget.apiKey,
    );
    _chat = _model.startChat();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textFieldDecoration = InputDecoration(
      contentPadding: const EdgeInsets.all(15),
      hintText: 'Ingresa un mensaje...',
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary),
      ),
    );

    if (_loading) {
      const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(),
                ),
              ),
            );
    }
          

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];

                      return MessageWidget(
                        text: message.text,
                        image: message.image,
                        isFromUser: message.fromUser,
                      );
                    },
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          autofocus: true,
                          focusNode: _textFieldFocus,
                          decoration: textFieldDecoration,
                          controller: _textController,
                          onSubmitted: _sendMessage,
                        ),
                      ),
                      const SizedBox.square(dimension: 15),
                      IconButton(
                        onPressed: !_loading
                            ? () async {
                                _pickImage(ImageSource.camera);
                              }
                            : null,
                        icon: Icon(
                          Icons.camera_alt,
                          color: _loading
                              ? Theme.of(context).colorScheme.secondary
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      IconButton(
                        onPressed: !_loading
                            ? () async {
                                _pickImage(ImageSource.gallery);
                              }
                            : null,
                        icon: Icon(
                          Icons.image,
                          color: _loading
                              ? Theme.of(context).colorScheme.secondary
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _sendMessage(_textController.text),
                        icon: Icon(
                          Icons.send,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeOutCirc,
      ),
    );
  }

  Future<void> _sendMessage(String message) async {
    if (message.isEmpty) {
      _showError('Por favor, escribe un mensaje.');
      _textFieldFocus.requestFocus();

      return;
    }

    setState(() {
      _loading = true;
      _messages.add((image: null, text: message, fromUser: true));
      _scrollDown();
    });

    try {
      final response = await _chat.sendMessage(Content.text(message));
      final text = response.text;

      setState(() {
        _messages.add((
          image: null,
          text: text ?? 'Sin respuesta del modelo.',
          fromUser: false
        ));
        _loading = false;
        _scrollDown();
      });
    } catch (e) {
      _showError(e.toString());
      setState(() {
        _loading = false;
      });
    } finally {
      _textController.clear();
      _textFieldFocus.requestFocus();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      final File imageFile = File(pickedFile.path);

      setState(() {
        _loading = true;
        _messages
            .add((image: Image.file(imageFile), text: null, fromUser: true));
      });

      // helps with the UI to scroll down to the image after is displayed
      Future.delayed(const Duration(milliseconds: 500), () {
        _scrollDown();
      });

      try {
        final bytes = await pickedFile.readAsBytes();
        final content = [
          Content.multi([
            DataPart('image/jpeg', bytes),
            TextPart(
                '¿Es esta imagen una planta? Toma el tiempo necesario para '
                'evaluar y así confirmar realmente si lo es.'),
          ]),
        ];

        var response = await _model.generateContent(content);
        var isPlant = response.text?.contains("planta") ?? false;

        if (isPlant) {
          final detailedPrompt = [
            Content.multi([
              DataPart('image/jpeg', bytes),
              TextPart('Identifica la planta en esta imagen, incluyendo su'
                  ' nombre científico si es posible. Describe las '
                  'características distintivas de la planta, como sus hojas, '
                  'flores o frutos. Compara la planta con otras similares y '
                  'explica las diferencias. Clasifica la planta según su '
                  'ecosistema o hábitat natural. Proporciona información '
                  'adicional sobre la planta, como sus propiedades medicinales '
                  'o usos tradicionales. Retorna el texto formateado, con '
                  'negrillas, titulos y cursivas cuando aplique.'),
            ]),
          ];

          var detailedResponse = await _model.generateContent(detailedPrompt);
          var detailedText = detailedResponse.text;

          _messages.add((image: null, text: detailedText, fromUser: false));
        } else {
          _messages.add((
            image: null,
            text: "La imagen no corresponde a una planta. Intenta nuevamente.",
            fromUser: false
          ));
        }

        setState(() {
          _loading = false;
          _scrollDown();
        });
      } catch (e) {
        _showError(e.toString());
        setState(() {
          _loading = false;
        });
      } finally {
        _textController.clear();
        setState(() {
          _loading = false;
        });
        _textFieldFocus.requestFocus();
      }
    }
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Algo salió mal'),
          content: SingleChildScrollView(
            child: SelectableText(message),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
