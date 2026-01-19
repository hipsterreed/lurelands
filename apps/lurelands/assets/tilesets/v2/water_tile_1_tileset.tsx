<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.11.2" name="water_tile_1" tilewidth="16" tileheight="16" tilecount="15" columns="3">
 <image source="../../images/terrain/Water_Tile_1.png" width="48" height="80"/>
 <tile id="0">
  <properties>
   <property name="is_fishable" type="bool" value="true"/>
  </properties>
  <objectgroup draworder="index" id="3">
   <object id="6" x="11" y="11.913" width="4.95652" height="4.13043"/>
  </objectgroup>
 </tile>
 <tile id="1">
  <properties>
   <property name="is_fishable" type="bool" value="true"/>
  </properties>
  <objectgroup draworder="index" id="2">
   <object id="1" x="0" y="9.95652" width="16" height="6"/>
  </objectgroup>
 </tile>
 <tile id="2">
  <properties>
   <property name="is_fishable" type="bool" value="true"/>
  </properties>
  <objectgroup draworder="index" id="2">
   <object id="1" x="0.0434783" y="11.913" width="5" height="4"/>
  </objectgroup>
 </tile>
 <tile id="3">
  <properties>
   <property name="is_fishable" type="bool" value="true"/>
  </properties>
  <objectgroup draworder="index" id="3">
   <object id="2" x="9" y="0" width="7" height="16"/>
  </objectgroup>
 </tile>
 <tile id="4">
  <properties>
   <property name="is_fishable" type="bool" value="true"/>
  </properties>
  <objectgroup draworder="index" id="2">
   <object id="3" x="0" y="0" width="16" height="16"/>
  </objectgroup>
 </tile>
 <tile id="5">
  <properties>
   <property name="is_fishable" type="bool" value="true"/>
  </properties>
  <objectgroup draworder="index" id="2">
   <object id="1" x="0.0434783" y="0" width="6.91304" height="16.0435"/>
  </objectgroup>
 </tile>
 <tile id="6">
  <properties>
   <property name="is_fishable" type="bool" value="true"/>
  </properties>
  <objectgroup draworder="index" id="2">
   <object id="1" x="11" y="-0.0434783" width="5" height="6"/>
  </objectgroup>
 </tile>
 <tile id="7">
  <properties>
   <property name="is_fishable" type="bool" value="true"/>
  </properties>
  <objectgroup draworder="index" id="2">
   <object id="1" x="0.0434783" y="-0.0869565" width="15.9565" height="8.04348"/>
  </objectgroup>
 </tile>
 <tile id="8">
  <properties>
   <property name="is_fishable" type="bool" value="true"/>
  </properties>
  <objectgroup draworder="index" id="2">
   <object id="1" x="0.0434783" y="0" width="6.08696" height="5.95652"/>
  </objectgroup>
 </tile>
 <tile id="9">
  <properties>
   <property name="is_fishable" type="bool" value="true"/>
  </properties>
  <objectgroup draworder="index" id="2">
   <object id="1" x="-0.0869565" y="-0.0434783" width="16.087" height="8.73913"/>
   <object id="2" x="-0.0869565" y="-0.0869565" width="8" height="15.9565"/>
  </objectgroup>
 </tile>
 <tile id="10">
  <properties>
   <property name="is_fishable" type="bool" value="true"/>
  </properties>
  <objectgroup draworder="index" id="2">
   <object id="1" x="0.0869565" y="0" width="15.9565" height="7.91304"/>
   <object id="4" x="9" y="0" width="7" height="15.9565"/>
  </objectgroup>
 </tile>
 <tile id="12">
  <properties>
   <property name="is_fishable" type="bool" value="true"/>
  </properties>
  <objectgroup draworder="index" id="2">
   <object id="1" x="0.0869565" y="0" width="6.91304" height="16.0435"/>
   <object id="2" x="0.0434783" y="7.91304" width="16" height="8.17391"/>
  </objectgroup>
 </tile>
 <tile id="13">
  <properties>
   <property name="is_fishable" type="bool" value="true"/>
  </properties>
  <objectgroup draworder="index" id="4">
   <object id="4" x="9" y="-0.0434783" width="7" height="16.0435"/>
   <object id="5" x="-0.0434783" y="8.95652" width="16.0435" height="7"/>
  </objectgroup>
 </tile>
 <wangsets>
  <wangset name="Water" type="corner" tile="-1">
   <wangcolor name="" color="#ff0000" tile="-1" probability="1"/>
   <wangtile tileid="0" wangid="0,0,0,1,0,0,0,0"/>
   <wangtile tileid="1" wangid="0,0,0,1,0,1,0,0"/>
   <wangtile tileid="2" wangid="0,0,0,0,0,1,0,0"/>
   <wangtile tileid="3" wangid="0,1,0,1,0,0,0,0"/>
   <wangtile tileid="4" wangid="0,1,0,1,0,1,0,1"/>
   <wangtile tileid="5" wangid="0,0,0,0,0,1,0,1"/>
   <wangtile tileid="6" wangid="0,1,0,0,0,0,0,0"/>
   <wangtile tileid="7" wangid="0,1,0,0,0,0,0,1"/>
   <wangtile tileid="8" wangid="0,0,0,0,0,0,0,1"/>
   <wangtile tileid="9" wangid="0,0,0,0,0,1,0,1"/>
   <wangtile tileid="10" wangid="0,1,0,1,0,0,0,1"/>
   <wangtile tileid="12" wangid="0,0,0,1,0,1,0,1"/>
   <wangtile tileid="13" wangid="0,1,0,1,0,1,0,0"/>
  </wangset>
 </wangsets>
</tileset>
