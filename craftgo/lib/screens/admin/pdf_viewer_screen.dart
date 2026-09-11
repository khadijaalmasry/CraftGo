import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

class PDFViewerScreen extends StatefulWidget {
  final String url;
  const PDFViewerScreen({super.key, required this.url});

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  String? _localPath;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPDF();
  }

  Future<void> _loadPDF() async {
    // On web: open in new tab and close this screen
    if (kIsWeb) {
      final uri = Uri.parse(widget.url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) Navigator.pop(context);
      } else {
        setState(() {
          _error = 'Cannot open URL';
          _isLoading = false;
        });
      }
      return;
    }

    // On mobile: download and view locally
    try {
      final response = await Dio().get(
        widget.url,
        options: Options(responseType: ResponseType.bytes),
      );
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(response.data);
      setState(() {
        _localPath = file.path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Viewer'),
        backgroundColor: const Color(0xFFD4A017),
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text('Error: $_error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                )
              : _buildMobileView(),
    );
  }

  Widget _buildMobileView() {
    return PDFView(
      filePath: _localPath,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: false,
      pageFling: true,
    );
  }
}
