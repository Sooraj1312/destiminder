import 'package:flutter/material.dart';

/// Clean Material 3 vector iconography system replacing legacy text emojis
class EmojiIcons {
  // ==================== HOME SCREEN TOP BAR ====================
  static Widget backgroundOn({double? size, Color? color}) => 
      Icon(Icons.sync_rounded, size: size ?? 24, color: color);
      
  static Widget backgroundOff({double? size, Color? color}) => 
      Icon(Icons.sync_disabled_rounded, size: size ?? 24, color: color);
      
  static Widget voiceOn({double? size, Color? color}) => 
      Icon(Icons.volume_up_rounded, size: size ?? 24, color: color);
      
  static Widget voiceOff({double? size, Color? color}) => 
      Icon(Icons.volume_off_rounded, size: size ?? 24, color: color);
      
  static Widget history({double? size, Color? color}) => 
      Icon(Icons.history_rounded, size: size ?? 24, color: color);
      
  static Widget notifications({double? size, Color? color}) => 
      Icon(Icons.notifications_active_rounded, size: size ?? 24, color: color);
      
  static Widget notificationsOff({double? size, Color? color}) => 
      Icon(Icons.notifications_off_rounded, size: size ?? 24, color: color);

  // ==================== DESTINATION CARD ====================
  static Widget activeDestination({double? size, Color? color}) => 
      Icon(Icons.navigation_rounded, size: size ?? 24, color: color);
      
  static Widget inactiveDestination({double? size, Color? color}) => 
      Icon(Icons.place_outlined, size: size ?? 24, color: color); 
      
  static Widget delete({double? size, Color? color}) => 
      Icon(Icons.delete_outline_rounded, size: size ?? 24, color: color);
      
  static Widget distanceWalk({double? size, Color? color}) => 
      Icon(Icons.directions_walk_rounded, size: size ?? 24, color: color);
      
  static Widget radiusIndicator({double? size, Color? color}) => 
      Icon(Icons.radar_rounded, size: size ?? 24, color: color);

  // ==================== DESTINATION DETAILS ====================
  static Widget location({double? size, Color? color}) => 
      Icon(Icons.place_rounded, size: size ?? 24, color: color);
      
  static Widget address({double? size, Color? color}) => 
      Icon(Icons.location_on_outlined, size: size ?? 24, color: color);
      
  static Widget radius({double? size, Color? color}) => 
      Icon(Icons.radar_rounded, size: size ?? 24, color: color);
      
  static Widget coordinates({double? size, Color? color}) => 
      Icon(Icons.map_rounded, size: size ?? 24, color: color);
      
  static Widget vibration({double? size, Color? color}) => 
      Icon(Icons.vibration_rounded, size: size ?? 24, color: color);
      
  static Widget voiceOnSmall({double? size, Color? color}) => 
      Icon(Icons.volume_up_rounded, size: size ?? 20, color: color);
      
  static Widget voiceOffSmall({double? size, Color? color}) => 
      Icon(Icons.volume_off_rounded, size: size ?? 20, color: color);
      
  static Widget close({double? size, Color? color}) => 
      Icon(Icons.close_rounded, size: size ?? 24, color: color);
      
  static Widget viewOnMap({double? size, Color? color}) => 
      Icon(Icons.map_rounded, size: size ?? 24, color: color);
      
  static Widget chevronRight({double? size, Color? color}) => 
      Icon(Icons.chevron_right_rounded, size: size ?? 24, color: color);

  // ==================== MAP PICKER ====================
  static Widget search({double? size, Color? color}) => 
      Icon(Icons.search_rounded, size: size ?? 24, color: color);
      
  static Widget back({double? size, Color? color}) => 
      Icon(Icons.arrow_back_rounded, size: size ?? 24, color: color);
      
  static Widget mapStyleLight({double? size, Color? color}) => 
      Icon(Icons.wb_sunny_rounded, size: size ?? 22, color: color);

  static Widget mapStyleDark({double? size, Color? color}) => 
      Icon(Icons.nightlight_round, size: size ?? 22, color: color);
      
  static Widget mapStyleSatellite({double? size, Color? color}) =>
      Icon(Icons.satellite_alt_rounded, size: size ?? 22, color: color); 
      
  static Widget currentLocation({double? size, Color? color}) => 
      Icon(Icons.my_location_rounded, size: size ?? 24, color: color);
      
  static Widget gpsFixed({double? size, Color? color}) => 
      Icon(Icons.gps_fixed_rounded, size: size ?? 24, color: color);
      
  static Widget selectedLocation({double? size, Color? color}) => 
      Icon(Icons.place_rounded, size: size ?? 24, color: color);
      
  static Widget editName({double? size, Color? color}) => 
      Icon(Icons.edit_rounded, size: size ?? 24, color: color);
      
  static Widget voiceToggleOn({double? size, Color? color}) => 
      Icon(Icons.volume_up_rounded, size: size ?? 24, color: color);
      
  static Widget voiceToggleOff({double? size, Color? color}) => 
      Icon(Icons.volume_off_rounded, size: size ?? 24, color: color);
      
  static Widget info({double? size, Color? color}) => 
      Icon(Icons.info_outline_rounded, size: size ?? 24, color: color);
      
  static Widget setDestination({double? size, Color? color}) => 
      Icon(Icons.check_circle_rounded, size: size ?? 24, color: color); 
      
  static Widget arrowDropDown({double? size, Color? color}) => 
      Icon(Icons.arrow_drop_down_rounded, size: size ?? 24, color: color);
      
  static Widget errorOutline({double? size, Color? color}) => 
      Icon(Icons.error_outline_rounded, size: size ?? 24, color: color);

  // ==================== HISTORY SCREEN ====================
  static Widget today({double? size, Color? color}) => 
      Icon(Icons.today_rounded, size: size ?? 24, color: color);
      
  static Widget deleteHistory({double? size, Color? color}) => 
      Icon(Icons.delete_sweep_rounded, size: size ?? 24, color: color);
      
  static Widget checkIn({double? size, Color? color}) => 
      Icon(Icons.check_circle_outline_rounded, size: size ?? 24, color: color);
      
  static Widget moreVert({double? size, Color? color}) => 
      Icon(Icons.more_vert_rounded, size: size ?? 24, color: color);
      
  static Widget share({double? size, Color? color}) => 
      Icon(Icons.share_rounded, size: size ?? 24, color: color);

  // ==================== LIVE MAP SCREEN ====================
  static Widget mapBack({double? size, Color? color}) => 
      Icon(Icons.arrow_back_rounded, size: size ?? 24, color: color);
      
  static Widget myLocation({double? size, Color? color}) => 
      Icon(Icons.my_location_rounded, size: size ?? 24, color: color);
      
  static Widget destinationFlag({double? size, Color? color}) => 
      Icon(Icons.flag_rounded, size: size ?? 24, color: color);
      
  static Widget celebration({double? size, Color? color}) => 
      Icon(Icons.celebration_rounded, size: size ?? 24, color: color);

  // ==================== ADD DESTINATION ====================
  static Widget addLocation({double? size, Color? color}) => 
      Icon(Icons.add_location_alt_rounded, size: size ?? 24, color: color);

  // ==================== STATUS ====================
  static Widget success({double? size, Color? color}) => 
      Icon(Icons.check_circle_rounded, size: size ?? 24, color: color);
      
  static Widget emojiEmotions({double? size, Color? color}) => 
      Icon(Icons.sentiment_very_satisfied_rounded, size: size ?? 24, color: color);
}
