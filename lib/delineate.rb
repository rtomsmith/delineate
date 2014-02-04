$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'core_extensions'
require 'active_record'

require 'delineate/map_attributes'
require 'delineate/attribute_map/csv_serializer'
require 'delineate/attribute_map/xml_serializer'
require 'delineate/attribute_map/json_serializer'

$LOAD_PATH.shift
