/// An annotation to mark Model classes that require a mapper
/// to their corresponding Entity class.
///
/// The annotated class (the Model) must extend the Entity class.
///
/// Example:
/// @ModelEntityMapper()
/// class MyModel extends MyEntity { ... }
class ModelEntityMapper {
  const ModelEntityMapper();
}

const modelEntityMapper = ModelEntityMapper();
