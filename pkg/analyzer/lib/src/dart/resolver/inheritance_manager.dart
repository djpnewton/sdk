// Copyright (c) 2016, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/standard_ast_factory.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/exception/exception.dart';
import 'package:analyzer/src/dart/ast/token.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:analyzer/src/dart/element/member.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/generated/type_system.dart';
import 'package:analyzer/src/generated/utilities_dart.dart';

/**
 * Instances of the class `InheritanceManager` manage the knowledge of where class members
 * (methods, getters & setters) are inherited from.
 */
@Deprecated('Use InheritanceManager2 instead.')
class InheritanceManager {
  /**
   * The [LibraryElement] that is managed by this manager.
   */
  LibraryElement _library;

  /**
   * A flag indicating whether abstract methods should be included when looking
   * up the superclass chain.
   */
  bool _includeAbstractFromSuperclasses;

  /**
   * This is a mapping between each [ClassElement] and a map between the [String] member
   * names and the associated [ExecutableElement] in the mixin and superclass chain.
   */
  Map<ClassElement, Map<String, ExecutableElement>> _classLookup;

  /**
   * This is a mapping between each [ClassElement] and a map between the [String] member
   * names and the associated [ExecutableElement] in the interface set.
   */
  Map<ClassElement, Map<String, ExecutableElement>> _interfaceLookup;

  /**
   * Initialize a newly created inheritance manager.
   *
   * @param library the library element context that the inheritance mappings are being generated
   */
  InheritanceManager(LibraryElement library,
      {bool includeAbstractFromSuperclasses: false}) {
    this._library = library;
    _includeAbstractFromSuperclasses = includeAbstractFromSuperclasses;
    _classLookup = new HashMap<ClassElement, Map<String, ExecutableElement>>();
    _interfaceLookup =
        new HashMap<ClassElement, Map<String, ExecutableElement>>();
  }

  /**
   * Set the new library element context.
   *
   * @param library the new library element
   */
  void set libraryElement(LibraryElement library) {
    this._library = library;
  }

  /**
   * Get and return a mapping between the set of all string names of the members inherited from the
   * passed [ClassElement] superclass hierarchy, and the associated [ExecutableElement].
   *
   * @param classElt the class element to query
   * @return a mapping between the set of all members inherited from the passed [ClassElement]
   *         superclass hierarchy, and the associated [ExecutableElement]
   */
  @Deprecated('Use InheritanceManager2.getInheritedConcreteMap() instead.')
  MemberMap getMapOfMembersInheritedFromClasses(ClassElement classElt) =>
      new MemberMap.fromMap(
          _computeClassChainLookupMap(classElt, new HashSet<ClassElement>()));

  /**
   * Get and return a mapping between the set of all string names of the members inherited from the
   * passed [ClassElement] interface hierarchy, and the associated [ExecutableElement].
   *
   * @param classElt the class element to query
   * @return a mapping between the set of all string names of the members inherited from the passed
   *         [ClassElement] interface hierarchy, and the associated [ExecutableElement].
   */
  @Deprecated('Use InheritanceManager2.getInheritedMap() instead.')
  MemberMap getMapOfMembersInheritedFromInterfaces(ClassElement classElt) =>
      new MemberMap.fromMap(
          _computeInterfaceLookupMap(classElt, new HashSet<ClassElement>()));

  /**
   * Return a table mapping the string names of the members inherited from the
   * passed [ClassElement]'s superclass hierarchy, and the associated executable
   * element.
   */
  @deprecated
  Map<String, ExecutableElement> getMembersInheritedFromClasses(
          ClassElement classElt) =>
      _computeClassChainLookupMap(classElt, new HashSet<ClassElement>());

  /**
   * Return a table mapping the string names of the members inherited from the
   * passed [ClassElement]'s interface hierarchy, and the associated executable
   * element.
   */
  @deprecated
  Map<String, ExecutableElement> getMembersInheritedFromInterfaces(
          ClassElement classElt) =>
      _computeInterfaceLookupMap(classElt, new HashSet<ClassElement>());

  /**
   * Given some [ClassElement] and some member name, this returns the
   * [ExecutableElement] that the class inherits from the mixins,
   * superclasses or interfaces, that has the member name, if no member is inherited `null` is
   * returned.
   *
   * @param classElt the class element to query
   * @param memberName the name of the executable element to find and return
   * @return the inherited executable element with the member name, or `null` if no such
   *         member exists
   */
  @Deprecated('Use InheritanceManager2.getInherited() instead.')
  ExecutableElement lookupInheritance(
      ClassElement classElt, String memberName) {
    if (memberName == null || memberName.isEmpty) {
      return null;
    }
    ExecutableElement executable = _computeClassChainLookupMap(
        classElt, new HashSet<ClassElement>())[memberName];
    if (executable == null) {
      return _computeInterfaceLookupMap(
          classElt, new HashSet<ClassElement>())[memberName];
    }
    return executable;
  }

  /**
   * Given some [ClassElement] and some member name, this returns the
   * [ExecutableElement] that the class either declares itself, or
   * inherits, that has the member name, if no member is inherited `null` is returned.
   *
   * @param classElt the class element to query
   * @param memberName the name of the executable element to find and return
   * @return the inherited executable element with the member name, or `null` if no such
   *         member exists
   */
  @Deprecated('Use InheritanceManager2.getMember() instead.')
  ExecutableElement lookupMember(ClassElement classElt, String memberName) {
    ExecutableElement element = _lookupMemberInClass(classElt, memberName);
    if (element != null) {
      return element;
    }
    return lookupInheritance(classElt, memberName);
  }

  /**
   * Determine the set of methods which is overridden by the given class member. If no member is
   * inherited, an empty list is returned. If one of the inherited members is a
   * [MultiplyInheritedExecutableElement], then it is expanded into its constituent inherited
   * elements.
   *
   * @param classElt the class to query
   * @param memberName the name of the class member to query
   * @return a list of overridden methods
   */
  @Deprecated('Use InheritanceManager2.getOverridden() instead.')
  List<ExecutableElement> lookupOverrides(
      ClassElement classElt, String memberName) {
    List<ExecutableElement> result = new List<ExecutableElement>();
    if (memberName == null || memberName.isEmpty) {
      return result;
    }
    List<Map<String, ExecutableElement>> interfaceMaps =
        _gatherInterfaceLookupMaps(classElt, new HashSet<ClassElement>());
    if (interfaceMaps != null) {
      for (Map<String, ExecutableElement> interfaceMap in interfaceMaps) {
        ExecutableElement overriddenElement = interfaceMap[memberName];
        if (overriddenElement != null) {
          if (overriddenElement is MultiplyInheritedExecutableElement) {
            for (ExecutableElement element
                in overriddenElement.inheritedElements) {
              result.add(element);
            }
          } else {
            result.add(overriddenElement);
          }
        }
      }
    }
    return result;
  }

  /**
   * Compute and return a mapping between the set of all string names of the members inherited from
   * the passed [ClassElement] superclass hierarchy, and the associated
   * [ExecutableElement].
   *
   * @param classElt the class element to query
   * @param visitedClasses a set of visited classes passed back into this method when it calls
   *          itself recursively
   * @return a mapping between the set of all string names of the members inherited from the passed
   *         [ClassElement] superclass hierarchy, and the associated [ExecutableElement]
   */
  Map<String, ExecutableElement> _computeClassChainLookupMap(
      ClassElement classElt, Set<ClassElement> visitedClasses) {
    Map<String, ExecutableElement> resultMap = _classLookup[classElt];
    if (resultMap != null) {
      return resultMap;
    } else {
      resultMap = new Map<String, ExecutableElement>();
    }
    InterfaceType supertype = classElt.supertype;
    if (supertype == null) {
      // classElt is Object or a mixin
      _classLookup[classElt] = resultMap;
      return resultMap;
    }
    ClassElement superclassElt = supertype.element;
    if (superclassElt != null) {
      if (!visitedClasses.contains(superclassElt)) {
        visitedClasses.add(superclassElt);
        try {
          resultMap = new Map<String, ExecutableElement>.from(
              _computeClassChainLookupMap(superclassElt, visitedClasses));
          //
          // Substitute the super types down the hierarchy.
          //
          _substituteTypeParametersDownHierarchy(supertype, resultMap);
          //
          // Include the members from the superclass in the resultMap.
          //
          _recordMapWithClassMembers(
              resultMap, supertype, _includeAbstractFromSuperclasses);
        } finally {
          visitedClasses.remove(superclassElt);
        }
      } else {
        // This case happens only when the superclass was previously visited and
        // not in the lookup, meaning this is meant to shorten the compute for
        // recursive cases.
        _classLookup[superclassElt] = resultMap;
        return resultMap;
      }
    }
    //
    // Include the members from the mixins in the resultMap.  If there are
    // multiple mixins, visit them in the order listed so that methods in later
    // mixins will overwrite identically-named methods in earlier mixins.
    //
    List<InterfaceType> mixins = classElt.mixins;
    for (InterfaceType mixin in mixins) {
      ClassElement mixinElement = mixin.element;
      if (mixinElement != null) {
        if (!visitedClasses.contains(mixinElement)) {
          visitedClasses.add(mixinElement);
          try {
            Map<String, ExecutableElement> map =
                new Map<String, ExecutableElement>();
            //
            // Include the members from the mixin in the resultMap.
            //
            _recordMapWithClassMembers(
                map, mixin, _includeAbstractFromSuperclasses);
            //
            // Add the members from map into result map.
            //
            for (String memberName in map.keys) {
              ExecutableElement value = map[memberName];
              ClassElement definingClass = value
                  .getAncestor((Element element) => element is ClassElement);
              if (!definingClass.type.isObject) {
                ExecutableElement existingValue = resultMap[memberName];
                if (existingValue == null ||
                    (existingValue != null && !_isAbstract(value))) {
                  resultMap[memberName] = value;
                }
              }
            }
          } finally {
            visitedClasses.remove(mixinElement);
          }
        } else {
          // This case happens only when the superclass was previously visited
          // and not in the lookup, meaning this is meant to shorten the compute
          // for recursive cases.
          _classLookup[mixinElement] = resultMap;
          return resultMap;
        }
      }
    }
    _classLookup[classElt] = resultMap;
    return resultMap;
  }

  /**
   * Compute and return a mapping between the set of all string names of the members inherited from
   * the passed [ClassElement] interface hierarchy, and the associated
   * [ExecutableElement].
   *
   * @param classElt the class element to query
   * @param visitedInterfaces a set of visited classes passed back into this method when it calls
   *          itself recursively
   * @return a mapping between the set of all string names of the members inherited from the passed
   *         [ClassElement] interface hierarchy, and the associated [ExecutableElement]
   */
  Map<String, ExecutableElement> _computeInterfaceLookupMap(
      ClassElement classElt, HashSet<ClassElement> visitedInterfaces) {
    Map<String, ExecutableElement> resultMap = _interfaceLookup[classElt];
    if (resultMap != null) {
      return resultMap;
    }
    List<Map<String, ExecutableElement>> lookupMaps =
        _gatherInterfaceLookupMaps(classElt, visitedInterfaces);
    if (lookupMaps == null) {
      resultMap = new Map<String, ExecutableElement>();
    } else {
      Map<String, List<ExecutableElement>> unionMap =
          _unionInterfaceLookupMaps(lookupMaps);
      resultMap = _resolveInheritanceLookup(classElt, unionMap);
    }
    _interfaceLookup[classElt] = resultMap;
    return resultMap;
  }

  /**
   * Given some array of [ExecutableElement]s, this method creates a synthetic element as
   * described in 8.1.1:
   *
   * Let <i>numberOfPositionals</i>(<i>f</i>) denote the number of positional parameters of a
   * function <i>f</i>, and let <i>numberOfRequiredParams</i>(<i>f</i>) denote the number of
   * required parameters of a function <i>f</i>. Furthermore, let <i>s</i> denote the set of all
   * named parameters of the <i>m<sub>1</sub>, &hellip;, m<sub>k</sub></i>. Then let
   * * <i>h = max(numberOfPositionals(m<sub>i</sub>)),</i>
   * * <i>r = min(numberOfRequiredParams(m<sub>i</sub>)), for all <i>i</i>, 1 <= i <= k.</i>
   * Then <i>I</i> has a method named <i>n</i>, with <i>r</i> required parameters of type
   * <b>dynamic</b>, <i>h</i> positional parameters of type <b>dynamic</b>, named parameters
   * <i>s</i> of type <b>dynamic</b> and return type <b>dynamic</b>.
   *
   */
  ExecutableElement _computeMergedExecutableElement(
      List<ExecutableElement> elementArrayToMerge) {
    int h = _getNumOfPositionalParameters(elementArrayToMerge[0]);
    int r = _getNumOfRequiredParameters(elementArrayToMerge[0]);
    Set<String> namedParametersList = new HashSet<String>();
    for (int i = 1; i < elementArrayToMerge.length; i++) {
      ExecutableElement element = elementArrayToMerge[i];
      int numOfPositionalParams = _getNumOfPositionalParameters(element);
      if (h < numOfPositionalParams) {
        h = numOfPositionalParams;
      }
      int numOfRequiredParams = _getNumOfRequiredParameters(element);
      if (r > numOfRequiredParams) {
        r = numOfRequiredParams;
      }
      // TODO(brianwilkerson) Handle the fact that named parameters can now be
      //  required.
      namedParametersList.addAll(_getNamedParameterNames(element));
    }
    return _createSyntheticExecutableElement(
        elementArrayToMerge,
        elementArrayToMerge[0].displayName,
        r,
        h - r,
        new List.from(namedParametersList));
  }

  /**
   * Used by [computeMergedExecutableElement] to actually create the
   * synthetic element.
   *
   * @param elementArrayToMerge the array used to create the synthetic element
   * @param name the name of the method, getter or setter
   * @param numOfRequiredParameters the number of required parameters
   * @param numOfPositionalParameters the number of positional parameters
   * @param namedParameters the list of [String]s that are the named parameters
   * @return the created synthetic element
   */
  ExecutableElement _createSyntheticExecutableElement(
      List<ExecutableElement> elementArrayToMerge,
      String name,
      int numOfRequiredParameters,
      int numOfPositionalParameters,
      List<String> namedParameters) {
    DynamicTypeImpl dynamicType = DynamicTypeImpl.instance;
    DartType bottomType = BottomTypeImpl.instance;
    SimpleIdentifier nameIdentifier = astFactory
        .simpleIdentifier(new StringToken(TokenType.IDENTIFIER, name, 0));
    ExecutableElementImpl executable;
    ExecutableElement elementToMerge = elementArrayToMerge[0];
    if (elementToMerge is MethodElement) {
      MultiplyInheritedMethodElementImpl unionedMethod =
          new MultiplyInheritedMethodElementImpl(nameIdentifier);
      unionedMethod.inheritedElements = elementArrayToMerge;
      executable = unionedMethod;
    } else if (elementToMerge is PropertyAccessorElement) {
      MultiplyInheritedPropertyAccessorElementImpl unionedPropertyAccessor =
          new MultiplyInheritedPropertyAccessorElementImpl(nameIdentifier);
      unionedPropertyAccessor.getter = elementToMerge.isGetter;
      unionedPropertyAccessor.setter = elementToMerge.isSetter;
      unionedPropertyAccessor.inheritedElements = elementArrayToMerge;
      executable = unionedPropertyAccessor;
    } else {
      throw new AnalysisException(
          'Invalid class of element in merge: ${elementToMerge.runtimeType}');
    }
    int numOfParameters = numOfRequiredParameters +
        numOfPositionalParameters +
        namedParameters.length;
    List<ParameterElement> parameters =
        new List<ParameterElement>(numOfParameters);
    int i = 0;
    for (int j = 0; j < numOfRequiredParameters; j++, i++) {
      ParameterElementImpl parameter = new ParameterElementImpl("", 0);
      parameter.type = bottomType;
      parameter.parameterKind = ParameterKind.REQUIRED;
      parameters[i] = parameter;
    }
    for (int k = 0; k < numOfPositionalParameters; k++, i++) {
      ParameterElementImpl parameter = new ParameterElementImpl("", 0);
      parameter.type = bottomType;
      parameter.parameterKind = ParameterKind.POSITIONAL;
      parameters[i] = parameter;
    }
    // TODO(brianwilkerson) Handle the fact that named parameters can now be
    //  required.
    for (int m = 0; m < namedParameters.length; m++, i++) {
      ParameterElementImpl parameter =
          new ParameterElementImpl(namedParameters[m], 0);
      parameter.type = bottomType;
      parameter.parameterKind = ParameterKind.NAMED;
      parameters[i] = parameter;
    }
    executable.returnType = dynamicType;
    executable.parameters = parameters;
    FunctionTypeImpl methodType = new FunctionTypeImpl(executable);
    executable.type = methodType;
    return executable;
  }

  /**
   * Collect a list of interface lookup maps whose elements correspond to all of the classes
   * directly above [classElt] in the class hierarchy (the direct superclass if any, all
   * mixins, and all direct superinterfaces). Each item in the list is the interface lookup map
   * returned by [computeInterfaceLookupMap] for the corresponding super, except with type
   * parameters appropriately substituted.
   *
   * @param classElt the class element to query
   * @param visitedInterfaces a set of visited classes passed back into this method when it calls
   *          itself recursively
   * @return `null` if there was a problem (such as a loop in the class hierarchy) or if there
   *         are no classes above this one in the class hierarchy. Otherwise, a list of interface
   *         lookup maps.
   */
  List<Map<String, ExecutableElement>> _gatherInterfaceLookupMaps(
      ClassElement classElt, HashSet<ClassElement> visitedInterfaces) {
    List<Map<String, ExecutableElement>> lookupMaps =
        new List<Map<String, ExecutableElement>>();
    bool hasProblem = false;

    void recordInterface(InterfaceType type) {
      ClassElement element = type.element;
      if (!visitedInterfaces.add(element)) {
        hasProblem = true;
        return;
      }
      try {
        //
        // Recursively compute the map for the interfaces.
        //
        Map<String, ExecutableElement> map =
            _computeInterfaceLookupMap(element, visitedInterfaces);
        map = new Map<String, ExecutableElement>.from(map);
        //
        // Substitute the supertypes down the hierarchy.
        //
        _substituteTypeParametersDownHierarchy(type, map);
        //
        // And any members from the interface into the map as well.
        //
        _recordMapWithClassMembers(map, type, true);
        lookupMaps.add(map);
      } finally {
        visitedInterfaces.remove(element);
      }
    }

    void recordInterfaces(List<InterfaceType> types) {
      for (int i = types.length - 1; i >= 0; i--) {
        InterfaceType type = types[i];
        recordInterface(type);
      }
    }

    InterfaceType superType = classElt.supertype;
    if (superType != null) {
      recordInterface(superType);
    }

    recordInterfaces(classElt.mixins);
    recordInterfaces(classElt.superclassConstraints);
    recordInterfaces(classElt.interfaces);

    if (hasProblem || lookupMaps.isEmpty) {
      return null;
    }
    return lookupMaps;
  }

  /**
   * Given some [classElement], this method finds and returns the executable
   * element with the given [memberName] in the class element. Static members,
   * members in super types and members not accessible from the current library
   * are not considered.
   */
  ExecutableElement _lookupMemberInClass(
      ClassElement classElement, String memberName) {
    List<MethodElement> methods = classElement.methods;
    int methodLength = methods.length;
    for (int i = 0; i < methodLength; i++) {
      MethodElement method = methods[i];
      if (memberName == method.name &&
          method.isAccessibleIn(_library) &&
          !method.isStatic) {
        return method;
      }
    }
    List<PropertyAccessorElement> accessors = classElement.accessors;
    int accessorLength = accessors.length;
    for (int i = 0; i < accessorLength; i++) {
      PropertyAccessorElement accessor = accessors[i];
      if (memberName == accessor.name &&
          accessor.isAccessibleIn(_library) &&
          !accessor.isStatic) {
        return accessor;
      }
    }
    return null;
  }

  /**
   * Record the passed map with the set of all members (methods, getters and setters) in the type
   * into the passed map.
   *
   * @param map some non-`null` map to put the methods and accessors from the passed
   *          [ClassElement] into
   * @param type the type that will be recorded into the passed map
   * @param doIncludeAbstract `true` if abstract members will be put into the map
   */
  void _recordMapWithClassMembers(Map<String, ExecutableElement> map,
      InterfaceType type, bool doIncludeAbstract) {
    Set<InterfaceType> seenTypes = new HashSet<InterfaceType>();
    while (type.element.isMixinApplication) {
      List<InterfaceType> mixins = type.mixins;
      if (!seenTypes.add(type) || mixins.isEmpty) {
        // In the case of a circularity in the type hierarchy, just don't add
        // any members to the map.
        return;
      }
      type = mixins.last;
    }
    List<MethodElement> methods = type.methods;
    for (MethodElement method in methods) {
      if (method.isAccessibleIn(_library) &&
          !method.isStatic &&
          (doIncludeAbstract || !method.isAbstract)) {
        map[method.name] = method;
      }
    }
    List<PropertyAccessorElement> accessors = type.accessors;
    for (PropertyAccessorElement accessor in accessors) {
      if (accessor.isAccessibleIn(_library) &&
          !accessor.isStatic &&
          (doIncludeAbstract || !accessor.isAbstract)) {
        map[accessor.name] = accessor;
      }
    }
  }

  /**
   * Given the set of methods defined by classes above [classElt] in the class hierarchy,
   * apply the appropriate inheritance rules to determine those methods inherited by or overridden
   * by [classElt].
   *
   * @param classElt the class element to query.
   * @param unionMap a mapping from method name to the set of unique (in terms of signature) methods
   *          defined in superclasses of [classElt].
   * @return the inheritance lookup map for [classElt].
   */
  Map<String, ExecutableElement> _resolveInheritanceLookup(
      ClassElement classElt, Map<String, List<ExecutableElement>> unionMap) {
    Map<String, ExecutableElement> resultMap =
        new Map<String, ExecutableElement>();
    unionMap.forEach((String key, List<ExecutableElement> list) {
      int numOfEltsWithMatchingNames = list.length;
      if (numOfEltsWithMatchingNames == 1) {
        //
        // Example: class A inherits only 1 method named 'm'.
        // Since it is the only such method, it is inherited.
        // Another example: class A inherits 2 methods named 'm' from 2
        // different interfaces, but they both have the same signature, so it is
        // the method inherited.
        //
        resultMap[key] = list[0];
      } else {
        //
        // Then numOfEltsWithMatchingNames > 1, check for the warning cases.
        //
        bool allMethods = true;
        bool allSetters = true;
        bool allGetters = true;
        for (ExecutableElement executableElement in list) {
          if (executableElement is PropertyAccessorElement) {
            allMethods = false;
            if (executableElement.isSetter) {
              allGetters = false;
            } else {
              allSetters = false;
            }
          } else {
            allGetters = false;
            allSetters = false;
          }
        }
        //
        // If there isn't a mixture of methods with getters, then continue,
        // otherwise create a warning.
        //
        if (allMethods || allGetters || allSetters) {
          //
          // Compute the element whose type is the subtype of all of the other
          // types.
          //
          List<ExecutableElement> elements = new List.from(list);
          List<FunctionType> executableElementTypes =
              new List<FunctionType>(numOfEltsWithMatchingNames);
          for (int i = 0; i < numOfEltsWithMatchingNames; i++) {
            executableElementTypes[i] = elements[i].type;
          }
          List<int> subtypesOfAllOtherTypesIndexes = new List<int>();
          for (int i = 0; i < numOfEltsWithMatchingNames; i++) {
            FunctionType subtype = executableElementTypes[i];
            if (subtype == null) {
              continue;
            }
            bool subtypeOfAllTypes = true;
            TypeSystem typeSystem = _library.context.typeSystem;
            for (int j = 0;
                j < numOfEltsWithMatchingNames && subtypeOfAllTypes;
                j++) {
              if (i != j) {
                if (!typeSystem.isSubtypeOf(
                    subtype, executableElementTypes[j])) {
                  subtypeOfAllTypes = false;
                  break;
                }
              }
            }
            if (subtypeOfAllTypes) {
              subtypesOfAllOtherTypesIndexes.add(i);
            }
          }
          //
          // The following is split into three cases determined by the number of
          // elements in subtypesOfAllOtherTypes
          //
          if (subtypesOfAllOtherTypesIndexes.length == 1) {
            //
            // Example: class A inherited only 2 method named 'm'.
            // One has the function type '() -> dynamic' and one has the
            // function type '([int]) -> dynamic'. Since the second method is a
            // subtype of all the others, it is the inherited method.
            // Tests: InheritanceManagerTest.
            // test_getMapOfMembersInheritedFromInterfaces_union_oneSubtype_*
            //
            resultMap[key] = elements[subtypesOfAllOtherTypesIndexes[0]];
          } else {
            if (subtypesOfAllOtherTypesIndexes.isNotEmpty) {
              //
              // Example: class A inherits 2 methods named 'm'.
              // One has the function type '(int) -> dynamic' and one has the
              // function type '(num) -> dynamic'. Since they are both a subtype
              // of the other, a synthetic function '(dynamic) -> dynamic' is
              // inherited.
              // Tests: test_getMapOfMembersInheritedFromInterfaces_
              // union_multipleSubtypes_*
              //
              // TODO(leafp): this produces (dynamic) -> dynamic even if
              // the types are equal which gives bad error messages. If
              // types are equal, we should consider using them.  Even
              // better, consider using the GLB of the parameter types
              // and the LUB of the return types
              List<ExecutableElement> elementArrayToMerge =
                  new List<ExecutableElement>(
                      subtypesOfAllOtherTypesIndexes.length);
              for (int i = 0; i < elementArrayToMerge.length; i++) {
                elementArrayToMerge[i] =
                    elements[subtypesOfAllOtherTypesIndexes[i]];
              }
              ExecutableElement mergedExecutableElement =
                  _computeMergedExecutableElement(elementArrayToMerge);
              resultMap[key] = mergedExecutableElement;
            }
          }
        }
      }
    });
    return resultMap;
  }

  /**
   * Loop through all of the members in the given [map], performing type
   * parameter  substitutions using a passed [supertype].
   */
  void _substituteTypeParametersDownHierarchy(
      InterfaceType superType, Map<String, ExecutableElement> map) {
    for (String memberName in map.keys) {
      ExecutableElement executableElement = map[memberName];
      if (executableElement is MethodMember) {
        map[memberName] = MethodMember.from(executableElement, superType);
      } else if (executableElement is PropertyAccessorMember) {
        map[memberName] =
            PropertyAccessorMember.from(executableElement, superType);
      }
    }
  }

  /**
   * Union all of the [lookupMaps] together into a single map, grouping the ExecutableElements
   * into a list where none of the elements are equal where equality is determined by having equal
   * function types. (We also take note too of the kind of the element: ()->int and () -> int may
   * not be equal if one is a getter and the other is a method.)
   *
   * @param lookupMaps the maps to be unioned together.
   * @return the resulting union map.
   */
  Map<String, List<ExecutableElement>> _unionInterfaceLookupMaps(
      List<Map<String, ExecutableElement>> lookupMaps) {
    Map<String, List<ExecutableElement>> unionMap =
        new HashMap<String, List<ExecutableElement>>();
    for (Map<String, ExecutableElement> lookupMap in lookupMaps) {
      for (String memberName in lookupMap.keys) {
        // Get the list value out of the unionMap
        List<ExecutableElement> list = unionMap.putIfAbsent(
            memberName, () => new List<ExecutableElement>());
        // Fetch the entry out of this lookupMap
        ExecutableElement newExecutableElementEntry = lookupMap[memberName];
        if (list.isEmpty) {
          // If the list is empty, just the new value
          list.add(newExecutableElementEntry);
        } else {
          // Otherwise, only add the newExecutableElementEntry if it isn't
          // already in the list, this covers situation where a class inherits
          // two methods (or two getters) that are identical.
          bool alreadyInList = false;
          bool isMethod1 = newExecutableElementEntry is MethodElement;
          for (ExecutableElement executableElementInList in list) {
            bool isMethod2 = executableElementInList is MethodElement;
            if (isMethod1 == isMethod2 &&
                executableElementInList.type ==
                    newExecutableElementEntry.type) {
              alreadyInList = true;
              break;
            }
          }
          if (!alreadyInList) {
            list.add(newExecutableElementEntry);
          }
        }
      }
    }
    return unionMap;
  }

  /**
   * Given some [ExecutableElement], return the list of named parameters.
   */
  static List<String> _getNamedParameterNames(
      ExecutableElement executableElement) {
    List<String> namedParameterNames = new List<String>();
    List<ParameterElement> parameters = executableElement.parameters;
    for (int i = 0; i < parameters.length; i++) {
      ParameterElement parameterElement = parameters[i];
      if (parameterElement.isNamed) {
        namedParameterNames.add(parameterElement.name);
      }
    }
    return namedParameterNames;
  }

  /**
   * Given some [ExecutableElement] return the number of parameters of the specified kind.
   */
  static int _getNumOfParameters(
      ExecutableElement executableElement, ParameterKind parameterKind) {
    int parameterCount = 0;
    List<ParameterElement> parameters = executableElement.parameters;
    for (int i = 0; i < parameters.length; i++) {
      ParameterElement parameterElement = parameters[i];
      // ignore: deprecated_member_use_from_same_package
      if (parameterElement.parameterKind == parameterKind) {
        parameterCount++;
      }
    }
    return parameterCount;
  }

  /**
   * Given some [ExecutableElement] return the number of positional parameters.
   *
   * Note: by positional we mean [ParameterKind.REQUIRED] or [ParameterKind.POSITIONAL].
   */
  static int _getNumOfPositionalParameters(
          ExecutableElement executableElement) =>
      _getNumOfParameters(executableElement, ParameterKind.REQUIRED) +
      _getNumOfParameters(executableElement, ParameterKind.POSITIONAL);

  /**
   * Given some [ExecutableElement] return the number of required parameters.
   */
  static int _getNumOfRequiredParameters(ExecutableElement executableElement) =>
      _getNumOfParameters(executableElement, ParameterKind.REQUIRED);

  /**
   * Given some [ExecutableElement] returns `true` if it is an abstract member of a
   * class.
   *
   * @param executableElement some [ExecutableElement] to evaluate
   * @return `true` if the given element is an abstract member of a class
   */
  static bool _isAbstract(ExecutableElement executableElement) {
    if (executableElement is MethodElement) {
      return executableElement.isAbstract;
    } else if (executableElement is PropertyAccessorElement) {
      return executableElement.isAbstract;
    }
    return false;
  }
}

/**
 * This class is used to replace uses of `HashMap<String, ExecutableElement>`
 * which are not as performant as this class.
 */
@deprecated
class MemberMap {
  /**
   * The current size of this map.
   */
  int _size = 0;

  /**
   * The array of keys.
   */
  List<String> _keys;

  /**
   * The array of ExecutableElement values.
   */
  List<ExecutableElement> _values;

  /**
   * Initialize a newly created member map to have the given [initialCapacity].
   * The map will grow if needed.
   */
  MemberMap([int initialCapacity = 10]) {
    _initArrays(initialCapacity);
  }

  /**
   * Initialize a newly created member map to contain the same members as the
   * given [memberMap].
   */
  MemberMap.from(MemberMap memberMap) {
    _initArrays(memberMap._size + 5);
    for (int i = 0; i < memberMap._size; i++) {
      _keys[i] = memberMap._keys[i];
      _values[i] = memberMap._values[i];
    }
    _size = memberMap._size;
  }

  /**
   * Initialize a newly created member map to contain the same members as the
   * given [map].
   */
  MemberMap.fromMap(Map<String, ExecutableElement> map) {
    _size = map.length;
    _initArrays(_size + 5);
    int index = 0;
    map.forEach((String memberName, ExecutableElement element) {
      _keys[index] = memberName;
      _values[index] = element;
      index++;
    });
  }

  /**
   * The size of the map.
   *
   * @return the size of the map.
   */
  int get size => _size;

  /**
   * Given some key, return the ExecutableElement value from the map, if the key does not exist in
   * the map, `null` is returned.
   *
   * @param key some key to look up in the map
   * @return the associated ExecutableElement value from the map, if the key does not exist in the
   *         map, `null` is returned
   */
  ExecutableElement get(String key) {
    for (int i = 0; i < _size; i++) {
      if (_keys[i] != null && _keys[i] == key) {
        return _values[i];
      }
    }
    return null;
  }

  /**
   * Get and return the key at the specified location. If the key/value pair has been removed from
   * the set, then `null` is returned.
   *
   * @param i some non-zero value less than size
   * @return the key at the passed index
   * @throw ArrayIndexOutOfBoundsException this exception is thrown if the passed index is less than
   *        zero or greater than or equal to the capacity of the arrays
   */
  String getKey(int i) => _keys[i];

  /**
   * Get and return the ExecutableElement at the specified location. If the key/value pair has been
   * removed from the set, then then `null` is returned.
   *
   * @param i some non-zero value less than size
   * @return the key at the passed index
   * @throw ArrayIndexOutOfBoundsException this exception is thrown if the passed index is less than
   *        zero or greater than or equal to the capacity of the arrays
   */
  ExecutableElement getValue(int i) => _values[i];

  /**
   * Given some key/value pair, store the pair in the map. If the key exists already, then the new
   * value overrides the old value.
   *
   * @param key the key to store in the map
   * @param value the ExecutableElement value to store in the map
   */
  void put(String key, ExecutableElement value) {
    // If we already have a value with this key, override the value
    for (int i = 0; i < _size; i++) {
      if (_keys[i] != null && _keys[i] == key) {
        _values[i] = value;
        return;
      }
    }
    // If needed, double the size of our arrays and copy values over in both
    // arrays
    if (_size == _keys.length) {
      int newArrayLength = _size * 2;
      List<String> keys_new_array = new List<String>(newArrayLength);
      List<ExecutableElement> values_new_array =
          new List<ExecutableElement>(newArrayLength);
      for (int i = 0; i < _size; i++) {
        keys_new_array[i] = _keys[i];
      }
      for (int i = 0; i < _size; i++) {
        values_new_array[i] = _values[i];
      }
      _keys = keys_new_array;
      _values = values_new_array;
    }
    // Put new value at end of array
    _keys[_size] = key;
    _values[_size] = value;
    _size++;
  }

  /**
   * Given some [String] key, this method replaces the associated key and value pair with
   * `null`. The size is not decremented with this call, instead it is expected that the users
   * check for `null`.
   *
   * @param key the key of the key/value pair to remove from the map
   */
  void remove(String key) {
    for (int i = 0; i < _size; i++) {
      if (_keys[i] == key) {
        _keys[i] = null;
        _values[i] = null;
        return;
      }
    }
  }

  /**
   * Sets the ExecutableElement at the specified location.
   *
   * @param i some non-zero value less than size
   * @param value the ExecutableElement value to store in the map
   */
  void setValue(int i, ExecutableElement value) {
    _values[i] = value;
  }

  /**
   * Initializes [keys] and [values].
   */
  void _initArrays(int initialCapacity) {
    _keys = new List<String>(initialCapacity);
    _values = new List<ExecutableElement>(initialCapacity);
  }
}
