import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:rubin_chart/src/core/data.dart';
import 'package:rubin_chart/src/core/unit.dart';


Future<Map<String, dynamic>> _readJson(String filename) async {
  developer.log("Loading $filename", name: "rubin_chart.io");
  final String response = await rootBundle.loadString(filename);
  final data = await json.decode(response);
  developer.log("$filename loaded", name: "rubin_chart.io");
  return data;
}


String _dateToFilename(String path, DateTime date) =>
  "$path/dayObs_${date.year}${date.month.toString().padLeft(2, "0")}"
      "${date.day.toString().padLeft(2, "0")}.json";


List<SchemaField> _getNightlyColumnFields(String dataSetName){
  return [
    SchemaField(
      name: "__50_sigma_source_count",
      unit: Unit.number,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "__50_sigma_sources",
      unit: Unit.number,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "__5_sigma_source_count",
      unit: Unit.number,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "airmass",
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "altitude",
      unit: Unit.deg,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "astrometric_bias",
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "astrometric_scatter",
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "azimuth",
      unit: Unit.deg,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "darktime",
      unit: Unit.s,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "dayobs",
      dataSetName: dataSetName,
      unit: Unit.date,
    ),
    SchemaField(
      name: "dec",
      dataSetName: dataSetName,
      unit: Unit.deg,
    ),
    SchemaField(
      name: "dimm_seeing",
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "disperser",
      unit: Unit.string,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "disperser_1",
      unit: Unit.string,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "exposure_id",
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "exposure_time",
      unit: Unit.s,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "filter",
      unit: Unit.string,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "filter_1",
      unit: Unit.string,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "focus_z",
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "group_id",
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "has_annotations_",
      unit: Unit.string,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "image_type",
      unit: Unit.string,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "image_type_1",
      unit: Unit.string,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "jira_ticket",
      unit: Unit.string,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "log_level",
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "log_message",
      unit: Unit.string,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "mount_jitter_rms",
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "mount_motion_image_degradation",
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "observation_reason",
      unit: Unit.string,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "observation_reason_1",
      unit: Unit.string,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "psf_e1",
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "psf_e2",
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "psf_fwhm",
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "psf_star_count",
      unit: Unit.number,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "quality_flag",
      unit: Unit.string,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "ra",
      unit: Unit.deg,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "science_program",
      unit: Unit.string,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "science_program_1",
      unit: Unit.string,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "seqnum",
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "sky_angle",
      unit: Unit.deg,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "sky_mean",
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "sky_rms",
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "tai",
      unit: Unit.date,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "target",
      unit: Unit.string,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "timestamp",
      unit: Unit.date,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "variance_plane_mean",
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "zenith_angle",
      unit: Unit.deg,
      dataSetName: dataSetName,
    ),
    SchemaField(
      name: "zeropoint",
      unit: Unit.mag,
      dataSetName: dataSetName,
    ),
  ];
}


const Map<String, String> _mapOldToNew = {
  "5-sigma source count": "__5_sigma_source_count",
  "50-sigma source count": "__50_sigma_source_count",
  "Airmass": "airmass",
  "Altitude": "altitude",
  "Astrometric bias": "astrometric_bias",
  "Astrometric scatter": "astrometric_scatter",
  "Azimuth": "azimuth",
  "DIMM Seeing": "dimm_Seeing",
  "Darktime": "darktime",
  "Dec": "dec",
  "Disperser": "disperser",
  "Exposure id": "exposure_id",
  "Exposure time": "exposre_time",
  "Filter": "filter",
  "Focus-Z": "focus_z",
  "Group id": "group_id",
  "Has annotations?": "has_annotations_",
  "Image type": "image_type",
  "Jira ticket": "jira_ticket",
  "Log level": "log_level",
  "Log message": "log_message",
  "Mount jitter RMS": "move_jitter_rms",
  "Mount motion image degradation": "mount_motion_image_degradation",
  "Observation reason": "observation_reason",
  "PSF FWHM": "psf_fwhm",
  "PSF e1": "psf_e1",
  "PSF e2": "psf_e2",
  "PSF star count": "psf_star_count",
  "Quality flag": "quality_flag",
  "RA": "ra",
  "Science program": "science_program",
  "Sky RMS": "sky_rms",
  "Sky angle": "sky_angle",
  "Sky mean": "sky_mean",
  "TAI": "tai",
  "Target": "target",
  "Variance plane mean": "variance_plane_mean",
  "Zenith angle": "zenith_angle",
  "Zeropoint": "zeropoint",
  "_5-sigma source count": "__5_sigma_source_count",
  "_50-sigma source count": "__50_sigma_source_count",
  "_Astrometric bias": "astrometric_bias",
  "_Astrometric scatter": "astrometric_scatter",
  "_Mount motion image degradation": "mount_motion_image_degradation",
  "_PSF FWHM": "psf_fwhm",
  "_PSF e1": "psf_e1",
  "_PSF e2": "psf_e2",
  "_PSF star count": "psf_star_count",
  "_Sky RMS": "sky_rms",
  "_Sky mean": "sky_mean",
  "_Variance plane mean": "variance_plane_mean",
  "_Zeropoint": "zeropoint",
  "dayObs": "dayobs",
  "seqNum": "seqnum",
};


DataSet<int> _nightlyToDataSet(Map<String, dynamic> data){
  Map<int, Map<String, dynamic>> result = {};

  for(Map<String, dynamic> entry in data.values){
    Map<String, dynamic> record = {};
    // Temporarily convert old JSON names to visitDB names
    for(String key in entry.keys){
      record[_mapOldToNew[key]!] = entry[key];
    }
    int id = record["exposure_id"];
    result[id] = record;
  }
  String name = "Nightly Report Data";
  return DataSet.init<int>(
    name: name,
    schema: Schema.fromFields(_getNightlyColumnFields(name)),
    data: result,
  );
}


Future<DataSet<int>> loadNightlyData(DateTime date) async {
  String filename = _dateToFilename("assets/tempdata", date);

  Map<String, dynamic> data = await _readJson(filename);

  return _nightlyToDataSet(data);
}
