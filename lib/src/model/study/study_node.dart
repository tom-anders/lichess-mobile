import 'package:chessground/chessground.dart';
import 'package:collection/collection.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/common/uci.dart';
import 'package:lichess_mobile/src/model/study/study_analysis.dart';

// TODO doc
abstract class StudyNode {
  StudyNode(
    StudyTreePart treePart, {
    required this.position,
  })  : fen = treePart.fen,
        comments = treePart.comments,
        glyphs = treePart.glyphs,
        shapes = treePart.shapes;

  /// Will only be null if this is the root node and it is an illegal position.
  final Position? position;

  final List<StudyBranch> children = [];

  final String fen;

  final IList<StudyNodeComment>? comments;

  final IList<StudyNodeGlyph>? glyphs;

  final IList<Shape>? shapes;

  /// Adds a child to this node.
  void addChild(StudyBranch branch) => children.add(branch);

  /// Gets the node at the given path.
  StudyNode nodeAt(UciPath path) {
    if (path.isEmpty) return this;
    final child = childById(path.head!);
    if (child != null) {
      return child.nodeAt(path.tail);
    } else {
      return this;
    }
  }

  /// Finds the child node with that id.
  StudyBranch? childById(UciCharPair id) {
    return children.firstWhereOrNull((node) => node.id == id);
  }

  /// Gets the parent node at the given path
  StudyNode parentAt(UciPath path) {
    return nodeAt(path.penultimate);
  }

  /// An iterable of all nodes on the mainline.
  Iterable<StudyBranch> get mainline sync* {
    StudyNode current = this;
    while (current.children.isNotEmpty) {
      final child = current.children.first;
      yield child;
      current = child;
    }
  }
}

// TODO doc
class StudyRoot extends StudyNode {
  StudyRoot(
    super.treePart, {
    required super.position,
  });

  // TODO consider keeping the structure fropm the server, i.e. have a List<MainlineNode> for the root
  // And a separate SideLineNode class for the sidelines

  factory StudyRoot.fromServerTreeParts(
    Iterable<StudyTreePart> treeParts,
    Variant variant,
  ) {
    if (treeParts.isEmpty) {
      throw Exception('Empty study analysis tree');
    }

    final position = () {
      try {
        return Position.setupPosition(
          variant.rule,
          Setup.parseFen(treeParts.first.fen),
        );
      } catch (e) {
        return null;
      }
    }();

    final rootPart = treeParts.first;
    final root = StudyRoot(
      rootPart,
      position: position,
    );

    if (treeParts.length > 1) {
      root.addChild(
        StudyBranch.fromServerTreeParts(treeParts.skip(1), variant),
      );
    }

    rootPart.children?.forEach((child) {
      root.addChild(StudyBranch.fromServerTreePart(child, variant));
    });

    return root;
  }

  @override
  String toString() {
    return 'Root(fen: ${position?.fen}, children: $children)';
  }
}

// TODO doc
class StudyBranch extends StudyNode {
  StudyBranch(
    super.treePart, {
    required Position super.position,
  })  : ply = treePart.ply,
        move = treePart.uci!,
        sanMove = treePart.san!,
        nags = treePart.glyphs?.map((glyph) => glyph.nag).toIList();

  final int ply;

  final UCIMove move;

  final String sanMove;

  final IList<int>? nags;

  /// The id of the branch, using a concise notation of associated move.
  UciCharPair get id => UciCharPair.fromMove(Move.parse(move)!);

  factory StudyBranch.fromServerTreeParts(
    Iterable<StudyTreePart> treeParts,
    Variant variant,
  ) {
    if (treeParts.isEmpty) {
      throw Exception('Empty study analysis tree');
    }

    final branch = StudyBranch(
      treeParts.first,
      position: Position.setupPosition(
        variant.rule,
        Setup.parseFen(treeParts.first.fen),
      ),
    );

    if (treeParts.length > 1) {
      branch.addChild(
        StudyBranch.fromServerTreeParts(treeParts.skip(1), variant),
      );
    }

    treeParts.first.children?.forEach((child) {
      branch.addChild(StudyBranch.fromServerTreePart(child, variant));
    });

    return branch;
  }

  factory StudyBranch.fromServerTreePart(
    StudyTreePart treePart,
    Variant variant,
  ) {
    final branch = StudyBranch(
      treePart,
      position: Position.setupPosition(
        variant.rule,
        Setup.parseFen(treePart.fen),
      ),
    );

    treePart.children?.forEach((child) {
      branch.addChild(StudyBranch.fromServerTreePart(child, variant));
    });

    return branch;
  }

  @override
  String toString() {
    return 'Branch(id: $id, fen: ${position!.fen}, sanMove: $sanMove, children: $children)';
  }
}
