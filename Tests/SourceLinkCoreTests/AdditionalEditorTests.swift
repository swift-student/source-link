import Foundation
@testable import SourceLinkCore
import Testing

struct AdditionalEditorTests {
  @Test(arguments: [Editor.androidStudio, .idea])
  func `jet brains positions`(_ editor: Editor) {
    let file = URL(fileURLWithPath: "/tmp/a file;$(echo bad).kt")
    #expect(EditorCommand(editor: editor, file: file, line: nil, column: nil).arguments == [file.path])
    #expect(EditorCommand(editor: editor, file: file, line: 12, column: nil).arguments
      == ["--line", "12", file.path])
    #expect(EditorCommand(editor: editor, file: file, line: 12, column: 3).arguments
      == ["--line", "12", "--column", "3", file.path])
  }

  @Test func `sublime positions`() {
    let file = URL(fileURLWithPath: "/tmp/a file;$(echo bad).md")
    #expect(EditorCommand(editor: .sublime, file: file, line: nil, column: nil).arguments == [file.path])
    #expect(EditorCommand(editor: .sublime, file: file, line: 12, column: nil).arguments == [file.path + ":12:1"])
    #expect(EditorCommand(editor: .sublime, file: file, line: 12, column: 3).arguments == [file.path + ":12:3"])
  }

  @Test(arguments: [Editor.androidStudio, .idea, .sublime])
  func `configuration round trip and routing`(_ editor: Editor) throws {
    let document = try ConfigurationDocument(text: """
    {"version":1,"default_editor":"\(editor.rawValue)",
     "executables":{"\(editor.rawValue)":"/custom/editor"},
     "rules":[{"extension":"kt","editor":"\(editor.rawValue)"}]}
    """)
    let restored = try ConfigurationDocument.initial(document.settings)
    #expect(restored.settings.hasSameConfiguration(as: document.settings))
    #expect(restored.settings.defaultEditor == editor)
    let file = URL(fileURLWithPath: "/tmp/example.kt")
    #expect(restored.settings.editor(for: file) == editor)
    let command = EditorCommand(editor: editor, executable: restored.settings.executablePaths[editor.rawValue],
                                file: file, line: 12, column: 3)
    #expect(command.executable == "/custom/editor")
    #expect(EditorCommand(editor: editor, executable: "", file: file, line: nil, column: nil).executable
      == editor.defaultExecutable)
  }
}
