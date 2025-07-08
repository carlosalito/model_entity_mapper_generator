import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:model_entity_mapper/annotation/model_entity_mapper_annotation.dart';
import 'package:source_gen/source_gen.dart';

const TypeChecker _modelEntityMapperChecker = TypeChecker.fromRuntime(ModelEntityMapper);
const TypeChecker _jsonKeyChecker = TypeChecker.fromRuntime(JsonKey);

class ModelEntityMapperGenerator extends GeneratorForAnnotation<ModelEntityMapper> {
  @override
  String generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '''The annotation @ModelEntityMapper can only be used on classes.''',
        element: element,
      );
    }

    final ClassElement modelClass = element;
    final InterfaceType? superType = modelClass.supertype;
    final String sourceFileName = element.library.source.shortName;

    if (superType == null || superType.element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '''The class ${modelClass.name} must extend another class (Entity).''',
        element: element,
      );
    }

    final ClassElement entityClass = superType.element as ClassElement;
    final StringBuffer buffer = StringBuffer();

    buffer.writeln("part of '$sourceFileName';\n");

    buffer.write(_generateToEntity(modelClass, entityClass));
    buffer.write('\n');
    buffer.write(_generateFromEntity(modelClass, entityClass));

    return buffer.toString();
  }

  String _generateToEntity(ClassElement modelClass, ClassElement entityClass) {
    final String modelClassName = modelClass.name;
    final String entityClassName = entityClass.name;
    final ConstructorElement? entityConstructor = entityClass.unnamedConstructor;
    if (entityConstructor == null) {
      throw InvalidGenerationSourceError(
        '''The Entity class $entityClassName must have a default constructor.''',
        element: entityClass,
      );
    }

    final buffer = StringBuffer();
    buffer.writeln('$entityClassName _\$${modelClassName}ToEntity($modelClassName model) {');
    buffer.writeln('  return $entityClassName(');

    for (final param in entityConstructor.parameters) {
      if (param.isSynthetic) continue;
      final String paramName = param.name;

      FieldElement? matchedField;
      for (final field in modelClass.fields) {
        final jsonKeyName = _getJsonKeyName(field);
        if (jsonKeyName == paramName || field.name == paramName || field.name == '${paramName}Model') {
          matchedField = field;
          break;
        }
      }

      String sourceValue = 'model.${matchedField?.name ?? paramName}';

      if (matchedField != null) {
        final bool isPrimitiveField = _isPrimitive(matchedField.type);
        final typeElement = (matchedField.type is InterfaceType) ? (matchedField.type as InterfaceType).element : null;
        final bool isModelEntityMapperField =
            typeElement != null && _modelEntityMapperChecker.hasAnnotationOf(typeElement);

        if (!isPrimitiveField && isModelEntityMapperField) {
          sourceValue += '.toEntity()';
        }
      }

      buffer.writeln('    $paramName: $sourceValue,');
    }

    buffer.writeln('  );');
    buffer.writeln('}');
    return buffer.toString();
  }

  String _generateFromEntity(ClassElement modelClass, ClassElement entityClass) {
    final String modelClassName = modelClass.name;
    final String entityClassName = entityClass.name;
    final ConstructorElement? modelConstructor = modelClass.unnamedConstructor;
    if (modelConstructor == null) {
      throw InvalidGenerationSourceError(
        '''The Model class $modelClassName must have a default constructor.''',
        element: modelClass,
      );
    }

    final buffer = StringBuffer();
    buffer.writeln('$modelClassName _\$${modelClassName}FromEntity($entityClassName entity) {');
    buffer.writeln('  return $modelClassName(');

    for (final param in modelConstructor.parameters) {
      if (param.isSynthetic) continue;

      final String paramName = param.name;
      String? entityFieldName = _getJsonKeyName(modelClass.getField(paramName)) ?? paramName;
      String sourceValue = 'entity.$entityFieldName';

      final typeElement = (param.type is InterfaceType) ? (param.type as InterfaceType).element : null;
      final isPrimitive = _isPrimitive(param.type);
      final isModelEntityMapper = typeElement != null && _modelEntityMapperChecker.hasAnnotationOf(typeElement);

      if (isModelEntityMapper && !isPrimitive) {
        sourceValue = '${typeElement.name}.fromEntity(entity.$entityFieldName)';
      }

      buffer.writeln('    $paramName: $sourceValue,');
    }

    buffer.writeln('  );');
    buffer.writeln('}');
    return buffer.toString();
  }

  String? _getJsonKeyName(FieldElement? field) {
    if (field == null) return null;
    final annotation = field.metadata.firstWhereOrNull(
      (e) => _jsonKeyChecker.isExactlyType(e.computeConstantValue()!.type!),
      orElse: () => null,
    );
    if (annotation == null) return null;
    final reader = ConstantReader(annotation.computeConstantValue());
    return reader.peek('name')?.stringValue;
  }

  bool _isPrimitive(DartType type) {
    return type.isDartCoreBool ||
        type.isDartCoreInt ||
        type.isDartCoreDouble ||
        type.isDartCoreNum ||
        type.isDartCoreString;
  }
}

extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test, {T? Function()? orElse}) {
    for (final element in this) {
      if (test(element)) {
        return element;
      }
    }
    return orElse != null ? orElse() : null;
  }
}
