import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/model_entity_mapper_generator.dart';

Builder modelEntityMapperBuilder(BuilderOptions options) {
  return LibraryBuilder(ModelEntityMapperGenerator(), generatedExtension: '.g.mapper.dart');
}
