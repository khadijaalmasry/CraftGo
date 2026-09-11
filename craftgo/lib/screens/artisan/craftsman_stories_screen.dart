import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/story_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/ai_service.dart';
import 'package:image_picker/image_picker.dart';

class CraftsmanStoriesScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final String artisanId;

  const CraftsmanStoriesScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.artisanId,
  });

  @override
  State<CraftsmanStoriesScreen> createState() => _CraftsmanStoriesScreenState();
}

class _CraftsmanStoriesScreenState extends State<CraftsmanStoriesScreen> {
  // Theme getters
  Color get bg =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white70 : Colors.black54;
  Color get border => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.08);
  Color get accent => const Color(0xFFD4A017);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  // Stories list loaded from backend
  List<Map<String, dynamic>> _stories = [];
  bool _loadingStories = true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _loadingStories = true);
    final data = await StoryService.getFeed();
    if (mounted) {
      setState(() {
        _stories = data.map((s) => {
          'id': s['id'] ?? '',
          'authorId': (s['artisanId'] ?? s['artisan']?['id'] ?? '').toString(),
          'author': (s['artisan']?['name'] ?? 'Artisan'),
          'authorAr': (s['artisan']?['name'] ?? 'حرفي'),
          'avatar': s['artisan']?['profileImage'],
          'textAr': s['textAr'] ?? '',
          'textEn': s['textEn'] ?? s['textAr'] ?? '',
          'image': s['imageUrl'],
          'timeAr': _formatTime(s['createdAt']),
          'timeEn': _formatTime(s['createdAt']),
          'likes': s['likes'] ?? 0,
          'comments': s['commentsCount'] ?? 0,
          'liked': (s['likedBy'] is List) && (s['likedBy'] as List).map((e) => e.toString()).contains(widget.artisanId),
        }).toList();
        _loadingStories = false;
      });
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return widget.isArabic ? 'منذ دقيقة' : '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return widget.isArabic ? 'منذ ساعة' : '${diff.inHours}h ago';
    return widget.isArabic ? 'منذ يوم' : '${diff.inDays}d ago';
  }


  Future<void> _postStory({bool openImagePicker = false}) async {
    final textController = TextEditingController();
    XFile? pickedImage;
    bool posting = false;
    bool suggestingCaption = false;

    if (openImagePicker) {
      pickedImage = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (pickedImage == null) return;
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Directionality(
          textDirection:
          widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border.all(color: border),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: dim.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t('انشر تحديثاً', 'Post an Update'),
                        style: GoogleFonts.cairo(
                          color: text,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (pickedImage != null) ...[
                        FutureBuilder<List<int>>(
                          future: pickedImage!.readAsBytes(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return SizedBox(
                                height: 150,
                                child: Center(
                                  child: CircularProgressIndicator(color: accent),
                                ),
                              );
                            }
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.memory(
                                    Uint8List.fromList(snapshot.data!),
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: IconButton.filled(
                                    onPressed: posting
                                        ? null
                                        : () => setSheetState(
                                          () => pickedImage = null,
                                    ),
                                    icon: const Icon(Icons.close),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black54,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: textController,
                        maxLines: 4,

                        textDirection:
                        widget.isArabic ? TextDirection.rtl : TextDirection.ltr,

                        textAlign:
                        widget.isArabic ? TextAlign.right : TextAlign.left,

                        style: GoogleFonts.cairo(
                          color: text,
                          height: 1.6,
                        ),

                        decoration: InputDecoration(
                          hintText: t(
                            'شارك مع متابعيك آخر أعمالك...',
                            'Share your latest work with followers...',
                          ),

                          hintTextDirection:
                          widget.isArabic ? TextDirection.rtl : TextDirection.ltr,

                          hintStyle: GoogleFonts.cairo(
                            color: dim,
                          ),

                          filled: true,
                          fillColor: widget.isDarkMode
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.02),

                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),

                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: posting || suggestingCaption
                              ? null
                              : () async {
                            final currentText =
                            textController.text.trim();

                            setSheetState(
                                  () => suggestingCaption = true,
                            );

                            final caption =
                            await AiService.generateStoryCaption(
                              topic: currentText.isEmpty
                                  ? t(
                                'مشاركة أحدث عمل يدوي',
                                'Sharing my latest handmade work',
                              )
                                  : currentText,
                              details: currentText,
                              language:
                              widget.isArabic ? 'ar' : 'en',
                            );

                            if (!ctx.mounted) return;

                            setSheetState(
                                  () => suggestingCaption = false,
                            );

                            if (caption == null || caption.isEmpty) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                    t(
                                      'تعذر اقتراح نص بالذكاء الاصطناعي',
                                      'Could not generate an AI caption',
                                    ),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            textController.text = caption;
                            textController.selection =
                                TextSelection.collapsed(
                                  offset: caption.length,
                                );
                          },
                          icon: suggestingCaption
                              ? SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accent,
                            ),
                          )
                              : Icon(Icons.auto_awesome, color: accent),
                          label: Text(
                            suggestingCaption
                                ? t('جارٍ الاقتراح...', 'Generating...')
                                : t(
                              'اقترح نصاً بالذكاء الاصطناعي',
                              'Suggest an AI Caption',
                            ),
                            style: GoogleFonts.cairo(
                              color: accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: accent),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: posting
                            ? null
                            : () async {
                          final image = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                          );
                          if (image != null) {
                            setSheetState(() => pickedImage = image);
                          }
                        },
                        icon: Icon(Icons.add_photo_alternate_outlined, color: accent),
                        label: Text(
                          pickedImage == null
                              ? t('إضافة صورة', 'Add Photo')
                              : t('تغيير الصورة', 'Change Photo'),
                          style: GoogleFonts.cairo(color: accent),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: accent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: posting
                              ? null
                              : () async {
                            final txt = textController.text.trim();
                            if (txt.isEmpty && pickedImage == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    t(
                                      'اكتبي نصاً أو اختاري صورة',
                                      'Write text or choose a photo',
                                    ),
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            setSheetState(() => posting = true);
                            String? imageUrl;
                            if (pickedImage != null) {
                              imageUrl = await CloudinaryService.uploadImage(
                                pickedImage!,
                              );
                              if (imageUrl == null) {
                                if (!ctx.mounted) return;
                                setSheetState(() => posting = false);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      t(
                                        'تعذر رفع الصورة',
                                        'Could not upload the photo',
                                      ),
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                            }

                            final result = await StoryService.createStory(
                              textAr: txt,
                              textEn: txt,
                              imageUrl: imageUrl,
                              artisanId: widget.artisanId,
                            );

                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);

                            if (result != null) {
                              await _loadFeed();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      t(
                                        'تم نشر التحديث ✅',
                                        'Update posted ✅',
                                      ),
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    StoryService.lastError == null
                                        ? t(
                                      '❌ فشل النشر',
                                      '❌ Failed to post',
                                    )
                                        : t(
                                      '❌ فشل النشر: ${StoryService.lastError}',
                                      '❌ Failed to post: ${StoryService.lastError}',
                                    ),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: posting
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                              : Text(
                            t('نشر', 'Post'),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteStory(Map<String, dynamic> story) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        title: Text(
          t('حذف القصة', 'Delete Story'),
          style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold),
        ),
        content: Text(
          t('هل أنت متأكد من حذف هذه القصة؟', 'Delete this story?'),
          style: GoogleFonts.cairo(color: dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('إلغاء', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              t('حذف', 'Delete'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final deleted = await StoryService.deleteStory(story['id'].toString());
    if (!mounted) return;
    if (deleted) {
      setState(() => _stories.remove(story));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('تم حذف القصة', 'Story deleted')),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('فشل حذف القصة', 'Failed to delete story')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  String _commentTime(dynamic raw) {
    final dt = DateTime.tryParse(raw?.toString() ?? '');
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return t('الآن', 'now');
    if (diff.inMinutes < 60) return t('منذ ${diff.inMinutes} د', '${diff.inMinutes}m ago');
    if (diff.inHours < 24) return t('منذ ${diff.inHours} س', '${diff.inHours}h ago');
    return t('منذ ${diff.inDays} يوم', '${diff.inDays}d ago');
  }

  Widget _avatar({
    String? imageUrl,
    required String name,
    double radius = 20,
  }) {
    final cleanUrl = imageUrl?.trim() ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: accent.withValues(alpha: 0.18),
      backgroundImage: cleanUrl.isNotEmpty ? NetworkImage(cleanUrl) : null,
      child: cleanUrl.isEmpty
          ? Text(
        name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase(),
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      )
          : null,
    );
  }

  Future<void> _showComments(Map<String, dynamic> story) async {
    final storyId = story['id']?.toString() ?? '';
    if (storyId.isEmpty) return;

    final commentController = TextEditingController();
    List<Map<String, dynamic>> comments = [];
    bool loading = true;
    bool sending = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> loadComments() async {
            final data = await StoryService.getComments(storyId);
            if (!sheetContext.mounted) return;
            setSheetState(() {
              comments = data;
              loading = false;
            });
          }

          if (loading && comments.isEmpty) {
            Future.microtask(loadComments);
          }

          Future<void> sendComment() async {
            final value = commentController.text.trim();
            if (value.isEmpty || sending) return;

            setSheetState(() => sending = true);
            final created = await StoryService.addComment(storyId, value);
            if (!sheetContext.mounted) return;

            if (created != null) {
              commentController.clear();
              setSheetState(() {
                comments.insert(0, created);
                sending = false;
              });
              if (mounted) {
                setState(() {
                  story['comments'] =
                      (int.tryParse((story['comments'] ?? 0).toString()) ?? 0) + 1;
                });
              }
            } else {
              setSheetState(() => sending = false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      t('تعذر إضافة التعليق', 'Could not add comment'),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }

          return Directionality(
            textDirection:
            widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Container(
                  height: MediaQuery.of(sheetContext).size.height * 0.72,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: dim.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                        child: Row(
                          children: [
                            Icon(Icons.forum_outlined, color: accent),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                t('التعليقات', 'Comments'),
                                style: GoogleFonts.cairo(
                                  color: text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              '${story['comments'] ?? 0}',
                              style: GoogleFonts.cairo(
                                color: dim,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: border),
                      Expanded(
                        child: loading
                            ? Center(
                          child: CircularProgressIndicator(color: accent),
                        )
                            : comments.isEmpty
                            ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 42,
                                  color: dim,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  t(
                                    'لا توجد تعليقات بعد',
                                    'No comments yet',
                                  ),
                                  style: GoogleFonts.cairo(
                                    color: text,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  t(
                                    'كوني أول من يضيف تعليقاً.',
                                    'Be the first to leave a comment.',
                                  ),
                                  style: GoogleFonts.cairo(
                                    color: dim,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                            : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: comments.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                          itemBuilder: (_, index) {
                            final comment = comments[index];
                            final name =
                            (comment['userName'] ?? 'User').toString();
                            final avatar =
                            comment['profileImage']?.toString();
                            final mine =
                                comment['userId']?.toString() ==
                                    widget.artisanId;
                            return Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                _avatar(
                                  imageUrl: avatar,
                                  name: name,
                                  radius: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(11),
                                    decoration: BoxDecoration(
                                      color: widget.isDarkMode
                                          ? Colors.white.withValues(
                                        alpha: 0.045,
                                      )
                                          : Colors.black.withValues(
                                        alpha: 0.035,
                                      ),
                                      borderRadius:
                                      BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style:
                                                GoogleFonts.cairo(
                                                  color: text,
                                                  fontSize: 12.5,
                                                  fontWeight:
                                                  FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _commentTime(
                                                comment['createdAt'],
                                              ),
                                              style:
                                              GoogleFonts.cairo(
                                                color: dim,
                                                fontSize: 9.5,
                                              ),
                                            ),
                                            if (mine) ...[
                                              const SizedBox(width: 4),
                                              IconButton(
                                                tooltip: t(
                                                  'حذف التعليق',
                                                  'Delete comment',
                                                ),
                                                onPressed: () async {
                                                  final commentId =
                                                      comment['id']
                                                          ?.toString() ??
                                                          '';
                                                  if (commentId.isEmpty) {
                                                    return;
                                                  }
                                                  final deleted =
                                                  await StoryService
                                                      .deleteComment(
                                                    storyId,
                                                    commentId,
                                                  );
                                                  if (!sheetContext
                                                      .mounted) {
                                                    return;
                                                  }
                                                  if (deleted) {
                                                    setSheetState(() {
                                                      comments
                                                          .removeAt(index);
                                                    });
                                                    if (mounted) {
                                                      setState(() {
                                                        story['comments'] =
                                                            ((int.tryParse((story['comments'] ?? 0).toString()) ??
                                                                0) -
                                                                1)
                                                                .clamp(
                                                              0,
                                                              999999,
                                                            );
                                                      });
                                                    }
                                                  }
                                                },
                                                icon: const Icon(
                                                  Icons
                                                      .delete_outline,
                                                  size: 17,
                                                  color: Colors
                                                      .redAccent,
                                                ),
                                                padding:
                                                EdgeInsets.zero,
                                                constraints:
                                                const BoxConstraints(),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          (comment['text'] ?? '')
                                              .toString(),
                                          style: GoogleFonts.cairo(
                                            color: text,
                                            fontSize: 12.5,
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      Divider(height: 1, color: border),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: commentController,
                                maxLines: 3,
                                minLines: 1,
                                style: GoogleFonts.cairo(color: text),
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => sendComment(),
                                decoration: InputDecoration(
                                  hintText: t(
                                    'اكتب تعليقاً...',
                                    'Write a comment...',
                                  ),
                                  hintStyle: GoogleFonts.cairo(color: dim),
                                  filled: true,
                                  fillColor: widget.isDarkMode
                                      ? Colors.white.withValues(alpha: 0.045)
                                      : Colors.black.withValues(alpha: 0.035),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: sending ? null : sendComment,
                              icon: sending
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                                  : const Icon(Icons.send_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    commentController.dispose();
  }

  Future<void> _showCreateStoryOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t('قصة جديدة', 'New Story'),
                style: GoogleFonts.cairo(
                  color: text,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.edit_outlined, color: accent),
                title: Text(
                  t('منشور نصي', 'Text Post'),
                  style: GoogleFonts.cairo(color: text),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _postStory();
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_outlined, color: accent),
                title: Text(
                  t('صورة', 'Photo'),
                  style: GoogleFonts.cairo(color: text),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _postStory(openImagePicker: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openStoryViewer(Map<String, dynamic> story) {
    final storyText =
        (widget.isArabic ? story['textAr'] : story['textEn'])
            ?.toString()
            .trim() ??
            '';
    final imageUrl = (story['image'] ?? '').toString().trim();
    final author =
        (widget.isArabic ? story['authorAr'] : story['author'])
            ?.toString()
            .trim() ??
            t('حرفي', 'Artisan');
    final time =
        (widget.isArabic ? story['timeAr'] : story['timeEn'])
            ?.toString()
            .trim() ??
            '';
    final heroTag = 'story-image-${story['id'] ?? imageUrl}';
    final isTextOnly = imageUrl.isEmpty;

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, __, ___) => Directionality(
          textDirection:
          widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 76, 18, 28),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height - 140,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Column(
                              mainAxisAlignment: isTextOnly
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Text-only stories get a deliberate, designed
                                // story card instead of looking like a missing image.
                                if (isTextOnly)
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1C2431),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.28),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            _avatar(
                                              imageUrl:
                                              story['avatar']?.toString(),
                                              name: author,
                                              radius: 22,
                                            ),
                                            const SizedBox(width: 11),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    author,
                                                    overflow:
                                                    TextOverflow.ellipsis,
                                                    style: GoogleFonts.cairo(
                                                      color: Colors.white,
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  if (time.isNotEmpty)
                                                    Text(
                                                      time,
                                                      style: GoogleFonts.cairo(
                                                        color: Colors.white54,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.format_quote_rounded,
                                              color: accent,
                                              size: 28,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          storyText,
                                          textAlign: widget.isArabic
                                              ? TextAlign.right
                                              : TextAlign.left,
                                          style: GoogleFonts.cairo(
                                            color: Colors.white,
                                            fontSize: 18,
                                            height: 1.8,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        Divider(
                                          color: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.favorite_border,
                                              color: Colors.white70,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              '${story['likes'] ?? 0}',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                            const Icon(
                                              Icons.chat_bubble_outline,
                                              color: Colors.white70,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              '${story['comments'] ?? 0}',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  )
                                else ...[
                                  Hero(
                                    tag: heroTag,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: AspectRatio(
                                        aspectRatio: 4 / 5,
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                                color: const Color(0xFF1C2431),
                                                alignment: Alignment.center,
                                                child: const Icon(
                                                  Icons.broken_image_outlined,
                                                  color: Colors.white54,
                                                  size: 52,
                                                ),
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (storyText.isNotEmpty) ...[
                                    const SizedBox(height: 18),
                                    Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1C2431),
                                        borderRadius:
                                        BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.1,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        storyText,
                                        textAlign: widget.isArabic
                                            ? TextAlign.right
                                            : TextAlign.left,
                                        style: GoogleFonts.cairo(
                                          color: Colors.white,
                                          fontSize: 16,
                                          height: 1.7,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF141B26),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      children: [
                                        _avatar(
                                          imageUrl:
                                          story['avatar']?.toString(),
                                          name: author,
                                          radius: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                author,
                                                overflow:
                                                TextOverflow.ellipsis,
                                                style: GoogleFonts.cairo(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (time.isNotEmpty)
                                                Text(
                                                  time,
                                                  style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.favorite_border,
                                          color: Colors.white70,
                                          size: 19,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${story['likes'] ?? 0}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        const Icon(
                                          Icons.chat_bubble_outline,
                                          color: Colors.white70,
                                          size: 19,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${story['comments'] ?? 0}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: 10,
                    start: 10,
                    child: IconButton.filled(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor:
                        Colors.black.withValues(alpha: 0.55),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 44),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_stories_outlined,
              size: 38,
              color: accent,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            t('لا توجد قصص بعد', 'No stories yet'),
            style: GoogleFonts.cairo(
              color: text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            t(
              'ابدئي بمشاركة أحدث أعمالك اليدوية مع المتابعين.',
              'Start by sharing your latest handmade work with followers.',
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: dim,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _showCreateStoryOptions,
            icon: const Icon(Icons.add, color: Colors.black),
            label: Text(
              t('إنشاء أول قصة', 'Create First Story'),
              style: GoogleFonts.cairo(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection:
      widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          foregroundColor: text,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            tooltip: t('رجوع', 'Back'),
            icon: Icon(
              widget.isArabic
                  ? Icons.arrow_forward_ios_rounded
                  : Icons.arrow_back_ios_new_rounded,
              color: text,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            t('القصص', 'Stories'),
            style: GoogleFonts.cairo(
              color: text,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreateStoryOptions,
          icon: const Icon(Icons.add),
          label: Text(
            t('قصة جديدة', 'New Story'),
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          backgroundColor: accent,
          foregroundColor: Colors.black,
        ),
        body: _loadingStories
            ? Center(
          child: CircularProgressIndicator(color: accent),
        )
            : RefreshIndicator(
          onRefresh: _loadFeed,
          color: accent,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _storyCircle(
                      onTap: () => _postStory(),
                      icon: Icons.add,
                      label: t('انشر', 'Post'),
                    ),
                    _storyCircle(
                      onTap: () =>
                          _postStory(openImagePicker: true),
                      icon: Icons.camera_alt_outlined,
                      label: t('صورة', 'Photo'),
                    ),

                  ],
                ),
              ),
              if (_stories.isEmpty)
                _buildEmptyState()
              else
                ..._stories.map(_buildStoryCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _storyCircle({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.1),
              border: Border.all(color: accent, width: 2),
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: dim,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryCard(Map<String, dynamic> story) {
    final author =
    (widget.isArabic ? story['authorAr'] : story['author'])
        ?.toString()
        .trim();
    final safeAuthor =
    (author == null || author.isEmpty)
        ? t('حرفي', 'Artisan')
        : author;

    final storyText =
        (widget.isArabic ? story['textAr'] : story['textEn'])
            ?.toString() ??
            '';

    final time =
        (widget.isArabic ? story['timeAr'] : story['timeEn'])
            ?.toString() ??
            '';

    final likes = int.tryParse((story['likes'] ?? 0).toString()) ?? 0;
    final comments =
        int.tryParse((story['comments'] ?? 0).toString()) ?? 0;
    final liked = story['liked'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(
                imageUrl: story['avatar']?.toString(),
                name: safeAuthor,
                radius: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      safeAuthor,
                      style: TextStyle(
                        color: text,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(color: dim, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (story['authorId'].toString() == widget.artisanId)
                PopupMenuButton<String>(
                  color: surface,
                  icon: Icon(Icons.more_vert, color: dim, size: 18),
                  onSelected: (value) {
                    if (value == 'delete') _deleteStory(story);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, color: Colors.redAccent),
                          const SizedBox(width: 8),
                          Text(
                            t('حذف', 'Delete'),
                            style: GoogleFonts.cairo(color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (storyText.trim().isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: Text(
                storyText,
                textDirection:
                widget.isArabic
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                textAlign:
                widget.isArabic
                    ? TextAlign.right
                    : TextAlign.left,
                softWrap: true,
                style: GoogleFonts.cairo(
                  color: text,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          if ((story['image'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _openStoryViewer(story),
              child: Hero(
                tag: 'story-image-${story['id'] ?? story['image']}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    story['image'].toString(),
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 170,
                      color: border,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: dim,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      color: liked ? Colors.redAccent : dim,
                      size: 20,
                    ),
                    onPressed: () {
                      // Toggle like via API
                      StoryService.toggleLike(story['id']).then((result) {
                        if (result != null && mounted) {
                          setState(() {
                            story['liked'] = result['liked'];
                            story['likes'] = result['likes'];
                          });
                        } else {
                          // Optimistic update fallback
                          setState(() {
                            story['liked'] = !liked;
                            story['likes'] += liked ? -1 : 1;
                          });
                        }
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    likes.toString(),
                    style: TextStyle(color: dim, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: () => _showComments(story),
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 20,
                        color: dim,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        comments.toString(),
                        style: TextStyle(color: dim, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showComments(story),
                icon: Icon(Icons.mode_comment_outlined, color: accent, size: 17),
                label: Text(
                  t('تعليق', 'Comment'),
                  style: GoogleFonts.cairo(
                    color: accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
