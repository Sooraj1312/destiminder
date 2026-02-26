import 'package:flutter/material.dart';

class EmojiIcons {

    // Helper method to center any emoji
  static Widget _centeredEmoji(String emoji, {double? size, Color? color}) {
    return Center(
      child: Text(
        emoji,
        style: TextStyle(
          fontSize: size ?? 24,
          color: color,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ==================== HOME SCREEN TOP BAR ====================
  static Widget backgroundOn({double? size, Color? color}) => 
      Text('🔄', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget backgroundOff({double? size, Color? color}) => 
      Text('🔄', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget voiceOn({double? size, Color? color}) => 
      Text('🔊', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget voiceOff({double? size, Color? color}) => 
      Text('🔇', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget history({double? size, Color? color}) => 
      Text('📜', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget notifications({double? size, Color? color}) => 
      Text('🔔', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget notificationsOff({double? size, Color? color}) => 
      Text('🔕', style: TextStyle(fontSize: size ?? 24, color: color));

  // ==================== DESTINATION CARD ====================
  static Widget activeDestination({double? size, Color? color}) => 
      _centeredEmoji('🧭', size: size, color: color);
      
  static Widget inactiveDestination({double? size, Color? color}) => 
      _centeredEmoji('📍', size: size, color: color); 
      
  static Widget delete({double? size, Color? color}) => 
      Text('🗑️', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget distanceWalk({double? size, Color? color}) => 
      Text('🚶', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget radiusIndicator({double? size, Color? color}) => 
      Text('📡', style: TextStyle(fontSize: size ?? 24, color: color));

  // ==================== DESTINATION DETAILS ====================
  static Widget location({double? size, Color? color}) => 
      Text('📍', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget address({double? size, Color? color}) => 
      Text('🏷️', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget radius({double? size, Color? color}) => 
      Text('📡', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget coordinates({double? size, Color? color}) => 
      Text('🗺️', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget vibration({double? size, Color? color}) => 
      Text('📳', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget voiceOnSmall({double? size, Color? color}) => 
      Text('🔊', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget voiceOffSmall({double? size, Color? color}) => 
      Text('🔇', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget close({double? size, Color? color}) => 
      Text('❌', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget viewOnMap({double? size, Color? color}) => 
      Text('🗺️', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget chevronRight({double? size, Color? color}) => 
      Text('➡️', style: TextStyle(fontSize: size ?? 24, color: color));

  // ==================== MAP PICKER ====================
  static Widget search({double? size, Color? color}) => 
      Text('🔍', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget back({double? size, Color? color}) => 
      Text('⬅️', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget mapStyleLight({double? size, Color? color}) => 
      _centeredEmoji('☀️', size: size, color: color);

  static Widget mapStyleDark({double? size, Color? color}) => 
      _centeredEmoji('🌙', size: size, color: color);
      
  static Widget mapStyleSatellite({double? size, Color? color}) =>
      _centeredEmoji('🛰️', size: size, color: color); 
    
      
  static Widget currentLocation({double? size, Color? color}) => 
      Text('🎯', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget gpsFixed({double? size, Color? color}) => 
      _centeredEmoji('📍', size: size, color: color);
      
  static Widget selectedLocation({double? size, Color? color}) => 
      Text('📍', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget editName({double? size, Color? color}) => 
      Text('✏️', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget voiceToggleOn({double? size, Color? color}) => 
      Text('🔊', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget voiceToggleOff({double? size, Color? color}) => 
      Text('🔇', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget info({double? size, Color? color}) => 
      Text('ℹ️', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget setDestination({double? size, Color? color}) => 
      _centeredEmoji('✅', size: size, color: color); 
      
  static Widget arrowDropDown({double? size, Color? color}) => 
      Text('⬇️', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget errorOutline({double? size, Color? color}) => 
      Text('❌', style: TextStyle(fontSize: size ?? 24, color: color));

  // ==================== HISTORY SCREEN ====================
  static Widget today({double? size, Color? color}) => 
      Text('📅', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget deleteHistory({double? size, Color? color}) => 
      Text('🗑️', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget checkIn({double? size, Color? color}) => 
      _centeredEmoji('✅', size: size, color: color);
      
  static Widget moreVert({double? size, Color? color}) => 
      Text('⋮', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget share({double? size, Color? color}) => 
      Text('📤', style: TextStyle(fontSize: size ?? 24, color: color));

  // ==================== LIVE MAP SCREEN ====================
  static Widget mapBack({double? size, Color? color}) => 
      Text('⬅️', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget myLocation({double? size, Color? color}) => 
      Text('🎯', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget destinationFlag({double? size, Color? color}) => 
      Text('🏁', style: TextStyle(fontSize: size ?? 24, color: color));
      
  static Widget celebration({double? size, Color? color}) => 
      Text('🎉', style: TextStyle(fontSize: size ?? 24, color: color));

  // ==================== ADD DESTINATION ====================
  static Widget addLocation({double? size, Color? color}) => 
      Text('➕', style: TextStyle(fontSize: size ?? 24, color: color));

  // ==================== STATUS ====================
  static Widget success({double? size, Color? color}) => 
      _centeredEmoji('✅', size: size, color: color);
      
  static Widget emojiEmotions({double? size, Color? color}) => 
      Text('😊', style: TextStyle(fontSize: size ?? 24, color: color));
}