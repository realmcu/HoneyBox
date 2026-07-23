// resource_pack.dart
//
// Bundles already-converted device resources (RGB565/ARGB8565/JPEG `.bin`s,
// AVI(CVID) clips, …) into one package with a small fixed header + per-resource
// offset table, plus a trailing thumbnail resource. Pure dart:typed_data so it
// stays testable and off the Flutter dependency, mirroring image_bin.dart.
//
// Package layout (all little-endian):
//   u8   type            resource type (see [ResourceType])
//   u8   resource_num    number of resources, INCLUDING the trailing thumbnail
//   u32  bg_color        background colour, 0x00RRGGBB ARGB8888 (alpha byte 0)
//   u32  size            total package size in bytes
//   u32  offset[num]     byte offset of each resource from the package start
//   ...  resource[0 .. num-2] payloads (the converted resources, in order)
//   ...  resource[num-1]      thumbnail payload (a 160×160 ARGB8565 `.bin`)
//
// The offset of resource i is where its bytes begin; its length is
// `offset[i+1] - offset[i]` (or `size - offset[num-1]` for the last one), so no
// per-resource length field is needed.

import 'dart:typed_data';

/// Values for the header's `type` byte (资源类型). Mirrors the firmware
/// `MAINFACE_SRC_TYPE` enum exactly:
///
/// ```c
/// typedef enum { SRC_IMG=0, SRC_VIDEO, SRC_3D, SRC_IMG_SPATIAL, SRC_DANMU }
/// MAINFACE_SRC_TYPE;
/// ```
class ResourceType {
  ResourceType._();
  static const int image = 0; // SRC_IMG
  static const int video = 1; // SRC_VIDEO
  static const int model3d = 2; // SRC_3D
  static const int imageSpatial = 3; // SRC_IMG_SPATIAL
  static const int danmaku = 4; // SRC_DANMU

  /// Short human-readable name for a `type` byte (for logs); 'unknown(N)' for
  /// values outside the enum.
  static String name(int type) {
    switch (type) {
      case image:
        return 'image';
      case video:
        return 'video';
      case model3d:
        return '3d';
      case imageSpatial:
        return 'spatial';
      case danmaku:
        return 'danmaku';
      default:
        return 'unknown($type)';
    }
  }
}

/// Fixed header bytes preceding the offset table:
/// type(1) + resource_num(1) + bg_color(4) + size(4).
const int kResourcePackHeaderBytes = 10;

/// Assemble [resources] (converted payloads, in order) plus a trailing
/// [thumbnail] into one package (see the file header for the byte layout).
///
/// [type] is the header's resource-type byte; [bgColor] is the background colour
/// as 0xAARRGGBB — the alpha (high) byte is forced to 0 when written, so the
/// header stores 0x00RRGGBB. `resource_num` is `resources.length + 1` (the
/// thumbnail is counted as the last resource). Throws [ArgumentError] if that
/// exceeds the u8 range (255).
Uint8List buildResourcePack({
  required int type,
  required int bgColor,
  required List<Uint8List> resources,
  required Uint8List thumbnail,
}) {
  final List<Uint8List> all = <Uint8List>[...resources, thumbnail];
  final int num = all.length;
  if (num > 255) {
    throw ArgumentError('资源数量 $num 超过 u8 resource_num 上限 (255)');
  }

  final int headerBytes = kResourcePackHeaderBytes + num * 4;

  // Offsets are relative to the package start; the first resource sits right
  // after the header + offset table.
  final List<int> offsets = List<int>.filled(num, 0);
  int cursor = headerBytes;
  for (int i = 0; i < num; i++) {
    offsets[i] = cursor;
    cursor += all[i].length;
  }
  final int total = cursor;

  final Uint8List out = Uint8List(total);
  final ByteData dv = ByteData.view(out.buffer);
  dv.setUint8(0, type & 0xFF);
  dv.setUint8(1, num & 0xFF);
  dv.setUint32(2, bgColor & 0x00FFFFFF, Endian.little); // ARGB, alpha byte 0
  dv.setUint32(6, total & 0xFFFFFFFF, Endian.little);
  for (int i = 0; i < num; i++) {
    dv.setUint32(
        kResourcePackHeaderBytes + i * 4, offsets[i] & 0xFFFFFFFF, Endian.little);
  }
  for (int i = 0; i < num; i++) {
    out.setRange(offsets[i], offsets[i] + all[i].length, all[i]);
  }
  return out;
}

/// A parsed package: the header fields plus each resource's byte range. The last
/// entry in [resources] is the thumbnail (see [thumbnail]).
class ResourcePack {
  final int type;

  /// Background colour as stored in the header: 0x00RRGGBB (alpha byte 0).
  final int bgColor;
  final int size;

  /// Byte offset of each resource from the package start, as read from the
  /// header's offset table (`offsets[i]` = start of resource `i`).
  final List<int> offsets;
  final List<Uint8List> resources;
  const ResourcePack({
    required this.type,
    required this.bgColor,
    required this.size,
    required this.offsets,
    required this.resources,
  });

  /// Number of resources, including the trailing thumbnail.
  int get resourceNum => resources.length;

  /// The trailing thumbnail resource, or null if the package is empty.
  Uint8List? get thumbnail => resources.isEmpty ? null : resources.last;

  /// One-line summary of the header (incl. the offset table) plus each
  /// resource's offset+size (last = thumbnail), for debug logging. e.g.
  /// `type=image(0) resources=2 bg=0x0000001f size=12345B offsets=[18, 8206] `
  /// `[res0@18=8188B, thumb@8206=4149B]`.
  String describeHeader() {
    final List<String> segs = <String>[
      for (int i = 0; i < resources.length; i++)
        '${i == resources.length - 1 ? 'thumb' : 'res$i'}'
            '@${offsets[i]}=${resources[i].length}B',
    ];
    return 'type=${ResourceType.name(type)}($type) '
        'resources=$resourceNum '
        'bg=0x${bgColor.toRadixString(16).padLeft(8, '0')} '
        'size=${size}B '
        'offsets=[${offsets.join(', ')}] '
        '[${segs.join(', ')}]';
  }
}

/// Parse a package produced by [buildResourcePack]. Returns null on short or
/// malformed input (bad `size`, out-of-range or non-monotonic offsets). Each
/// returned resource is a view into [bytes] (no copy). Provided for round-trip
/// testing and as executable documentation of the layout.
ResourcePack? parseResourcePack(Uint8List bytes) {
  if (bytes.length < kResourcePackHeaderBytes) return null;
  final ByteData dv = ByteData.sublistView(bytes);
  final int type = dv.getUint8(0);
  final int num = dv.getUint8(1);
  final int bgColor = dv.getUint32(2, Endian.little) & 0x00FFFFFF;
  final int size = dv.getUint32(6, Endian.little);
  if (num < 1) return null;
  final int headerBytes = kResourcePackHeaderBytes + num * 4;
  if (bytes.length < headerBytes) return null;
  if (size != bytes.length) return null;

  final List<int> offsets = List<int>.filled(num, 0);
  for (int i = 0; i < num; i++) {
    offsets[i] = dv.getUint32(kResourcePackHeaderBytes + i * 4, Endian.little);
  }

  final List<Uint8List> resources = <Uint8List>[];
  for (int i = 0; i < num; i++) {
    final int start = offsets[i];
    final int end = (i + 1 < num) ? offsets[i + 1] : size;
    if (start < headerBytes || end > bytes.length || end < start) return null;
    resources.add(Uint8List.sublistView(bytes, start, end));
  }
  return ResourcePack(
    type: type,
    bgColor: bgColor,
    size: size,
    offsets: offsets,
    resources: resources,
  );
}

/// The primary (first) resource of a package built by [buildResourcePack], or
/// null if [bytes] is not a package. Lets a caller that stored a package
/// transparently recover the payload it wraps (resource[0] — the converted
/// image / video / danmaku) while staying backward-compatible with pre-packaging
/// data: a bare `.bin` / AVI is not a valid package (its `resource_num` byte and
/// `size` field won't line up), so [parseResourcePack] returns null here and the
/// caller falls back to using the bytes as-is.
Uint8List? packagePrimaryResource(Uint8List bytes) {
  final ResourcePack? pack = parseResourcePack(bytes);
  if (pack == null || pack.resources.isEmpty) return null;
  return pack.resources.first;
}
