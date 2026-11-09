/// Device-initiated `cmd 0x07` events delivered by [JWControl].
abstract class JWControlListener {
  /// Watch gestured while [JWControl.setTakePhotoControl] is enabled.
  void onTakePhoto();

  /// Find-phone from the watch (`0x02` legacy or `0x1C` with on/off).
  void onFindPhone({required bool enable});

  /// Watch music keys: `0` play, `1` pause, `2` toggle, `3` next, `4` previous,
  /// `5` volume up, `6` volume down (same codes as Android V2 callbacks).
  void onMusicControl(int control);
}
