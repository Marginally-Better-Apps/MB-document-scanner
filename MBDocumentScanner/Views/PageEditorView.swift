import PencilKit
import SwiftUI
import UIKit

enum EditorDrawingInputMode: String, CaseIterable, Identifiable {
    case finger
    case pencil

    var id: Self { self }

    var title: String {
        switch self {
        case .finger: "Finger"
        case .pencil: "Apple Pencil"
        }
    }

    var systemImage: String {
        switch self {
        case .finger: "hand.draw"
        case .pencil: "applepencil"
        }
    }

    var pencilKitPolicy: PKCanvasViewDrawingPolicy {
        switch self {
        case .finger: .anyInput
        case .pencil: .pencilOnly
        }
    }
}

struct PageEditorView: View {
    let image: UIImage
    let pageNumber: Int
    let onCancel: () -> Void
    let onComplete: (UIImage) -> Void

    @State private var selectedTool = EditorTool.select
    @State private var selectedInstrument = DrawingInstrument.pen
    @State private var drawing = PKDrawing()
    @State private var textEdits: [PageTextEdit] = []
    @State private var redactions: [PageRedactionEdit] = []
    @State private var selection: EditorSelection?
    @GestureState private var draftRedactionFrame: CGRect?
    @State private var textEditorDraft: TextEditorDraft?
    @State private var undoStack: [EditorSnapshot] = []
    @State private var redoStack: [EditorSnapshot] = []
    @State private var isRecordingStroke = false
    @State private var inkColor = PageMarkupColor.blue
    @State private var relativeInkWidth: CGFloat = 0.008
    @State private var isRendering = false
    @State private var isDiscardConfirmationPresented = false
    @State private var isRedactionConfirmationPresented = false
    @State private var zoomResetID = 0
    @AppStorage("pageEditor.drawingInput") private var storedInputMode = EditorDrawingInputMode.finger.rawValue

    private var drawingInputMode: EditorDrawingInputMode {
        EditorDrawingInputMode(rawValue: storedInputMode) ?? .finger
    }

    private var canonicalCanvasSize: CGSize {
        guard image.size.width > 0, image.size.height > 0 else {
            return CGSize(width: 1_000, height: 1_000)
        }
        return CGSize(width: 1_000, height: 1_000 * image.size.height / image.size.width)
    }

    private var hasChanges: Bool {
        !drawing.strokes.isEmpty || !textEdits.isEmpty || !redactions.isEmpty
    }

    var body: some View {
        NavigationStack {
            workspace
            .background(ScanTheme.background)
            .navigationTitle("Page \(pageNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { editorToolbar }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                editingPalette
            }
        }
        .tint(ScanTheme.accent)
        .interactiveDismissDisabled(hasChanges || isRendering)
        .sheet(item: $textEditorDraft) { draft in
            TextEditSheet(
                draft: draft,
                onCancel: { textEditorDraft = nil },
                onSave: saveTextEdit
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Discard all edits?",
            isPresented: $isDiscardConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Discard Edits", role: .destructive, action: onCancel)
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("The scanned page will stay unchanged.")
        }
        .alert(redactionConfirmationTitle, isPresented: $isRedactionConfirmationPresented) {
            Button("Redact & Save", role: .destructive, action: renderAndComplete)
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Covered pixels and recognized text will be removed from this page. This can’t be undone after saving.")
        }
        .overlay {
            if isRendering {
                ZStack {
                    Color.black.opacity(0.42).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text(redactions.isEmpty ? "Applying edits…" : "Removing redacted content…")
                            .font(.headline)
                    }
                    .padding(.horizontal, 26)
                    .padding(.vertical, 22)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .onAppear {
            if UIDevice.current.userInterfaceIdiom != .pad {
                storedInputMode = EditorDrawingInputMode.finger.rawValue
            }
        }
    }

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                if hasChanges {
                    isDiscardConfirmationPresented = true
                } else {
                    onCancel()
                }
            }
            .disabled(isRendering)
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: undo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(undoStack.isEmpty || isRendering)
            .accessibilityLabel("Undo")

            Button(action: redo) {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(redoStack.isEmpty || isRendering)
            .accessibilityLabel("Redo")

            Button("Done", action: requestSave)
                .fontWeight(.semibold)
                .disabled(!hasChanges || isRendering)
        }
    }

    private var workspace: some View {
        ZStack(alignment: .top) {
            ScanTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                interactionStatus
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                GeometryReader { geometry in
                    let pageSize = aspectFitSize(
                        imageSize: image.size,
                        availableSize: CGSize(
                            width: max(1, geometry.size.width - 32),
                            height: max(1, geometry.size.height - 24)
                        )
                    )

                    ZoomableEditorPage(pageSize: pageSize, resetID: zoomResetID) {
                        editorPage(size: pageSize)
                    }
                }
                .clipped()

                HStack {
                    Text("Pinch to zoom · Two fingers to pan")
                        .font(.caption)
                    Spacer(minLength: 8)
                    Button("Fit Page") { zoomResetID += 1 }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ScanTheme.accent)
                        .frame(minHeight: 36)
                        .accessibilityHint("Reset the zoom to show the entire page")
                }
                .foregroundStyle(ScanTheme.secondaryInk)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func editorPage(size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            Image(uiImage: image)
                .resizable()
                .frame(width: size.width, height: size.height)

            CanonicalPencilCanvas(
                drawing: $drawing,
                canonicalSize: canonicalCanvasSize,
                tool: activePencilTool,
                drawingPolicy: drawingInputMode.pencilKitPolicy,
                isActive: selectedTool == .draw,
                directManipulationTargets: directManipulationTargets,
                selectedDirectTarget: selection,
                allowsDirectManipulation: selectedTool == .draw && drawingInputMode == .pencil,
                onStrokeBegan: beginDrawingStroke,
                onStrokeEnded: finishDrawingStroke,
                onPencilDetected: activatePencilInput,
                onDirectSelect: { selection = $0 },
                onDirectManipulationBegan: pushUndoSnapshot,
                onDirectFrameChanged: updateFrameWithoutHistory
            )
            .frame(width: size.width, height: size.height)
            .zIndex(selectedTool == .draw ? 10 : 1)

            placementLayer(canvasSize: size)
                .zIndex(2)

            ForEach(textEdits) { edit in
                TextEditOverlay(
                    edit: edit,
                    canvasSize: size,
                    isSelected: selection == .text(edit.id),
                    isInteractionEnabled: selectedTool == .select,
                    onSelect: {
                        selection = .text(edit.id)
                        selectedTool = .select
                    },
                    onEdit: { beginEditingText(edit) },
                    onMove: { newFrame in updateTextFrame(id: edit.id, frame: newFrame) },
                    onResize: { newFrame in updateTextFrame(id: edit.id, frame: newFrame) },
                    onDelete: { deleteSelection(.text(edit.id)) }
                )
                .zIndex(selectedTool == .draw ? 11 : 3)
            }

            ForEach(redactions) { redaction in
                RedactionEditOverlay(
                    redaction: redaction,
                    canvasSize: size,
                    isSelected: selection == .redaction(redaction.id),
                    isInteractionEnabled: selectedTool == .select,
                    onSelect: {
                        selection = .redaction(redaction.id)
                        selectedTool = .select
                    },
                    onMove: { newFrame in updateRedactionFrame(id: redaction.id, frame: newFrame) },
                    onResize: { newFrame in updateRedactionFrame(id: redaction.id, frame: newFrame) },
                    onDelete: { deleteSelection(.redaction(redaction.id)) }
                )
                .zIndex(selectedTool == .draw ? 12 : 4)
            }

            if let draftRedactionFrame {
                Rectangle()
                    .fill(Color.black.opacity(0.78))
                    .overlay {
                        Rectangle()
                            .stroke(Color.red, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    }
                    .frame(
                        width: draftRedactionFrame.width * size.width,
                        height: draftRedactionFrame.height * size.height
                    )
                    .position(
                        x: draftRedactionFrame.midX * size.width,
                        y: draftRedactionFrame.midY * size.height
                    )
                    .allowsHitTesting(false)
                    .zIndex(5)
            }
        }
        .frame(width: size.width, height: size.height)
        .background(Color.white)
        .clipped()
        .shadow(color: .black.opacity(0.12), radius: 18, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Editable scanned page")
    }

    @ViewBuilder
    private func placementLayer(canvasSize: CGSize) -> some View {
        switch selectedTool {
        case .select:
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { selection = nil }

        case .text:
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture().onEnded { value in
                        prepareNewText(at: normalized(value.location, in: canvasSize))
                    }
                )

        case .redact:
            Color.clear
                .contentShape(Rectangle())
                .gesture(redactionGesture(in: canvasSize))

        case .draw:
            Color.clear
                .allowsHitTesting(false)
        }
    }

    private var interactionStatus: some View {
        Label(statusText, systemImage: statusIcon)
            .font(.footnote)
            .foregroundStyle(ScanTheme.secondaryInk)
            .multilineTextAlignment(.center)
            .contentTransition(.opacity)
            .accessibilityLabel(statusText)
    }

    private var statusText: String {
        switch selectedTool {
        case .select:
            selection == nil ? "Tap an item to move or resize" : "Drag to move · Use the corner handle to resize"
        case .text:
            "Tap the page to add text"
        case .redact:
            "Drag over content to remove permanently"
        case .draw:
            drawingInputMode == .pencil
                ? "Apple Pencil draws · Touch moves and resizes"
                : "One finger draws · Apple Pencil switches automatically"
        }
    }

    private var statusIcon: String {
        switch selectedTool {
        case .select: "arrow.up.and.down.and.arrow.left.and.right"
        case .text: "textformat"
        case .redact: "lock.fill"
        case .draw: drawingInputMode.systemImage
        }
    }

    private var editingPalette: some View {
        VStack(spacing: 12) {
            contextualControls
                .frame(maxWidth: 720)
                .padding(.horizontal, 20)

            FloatingActionBar {
                ForEach(EditorTool.allCases) { tool in
                    EditorToolButton(tool: tool, isSelected: selectedTool == tool) {
                        withAnimation(.snappy(duration: 0.18)) {
                            selectedTool = tool
                            if tool == .text || tool == .redact { selection = nil }
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
            }
            .frame(maxWidth: 520)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var contextualControls: some View {
        switch selectedTool {
        case .select:
            selectionControls
        case .text:
            HStack(spacing: 10) {
                Label("Tap the page to place a text box", systemImage: "text.cursor")
                    .font(.subheadline)
                    .foregroundStyle(ScanTheme.secondaryInk)
                Spacer()
                Button("Add Center") {
                    prepareNewText(at: CGPoint(x: 0.5, y: 0.35))
                }
                .buttonStyle(ScanSecondaryButtonStyle())
            }
        case .redact:
            HStack(spacing: 10) {
                Label("Permanent", systemImage: "lock.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.red, in: Capsule())
                Text("Drag a box over private content. Pixels are removed when saved.")
                    .font(.footnote)
                    .foregroundStyle(ScanTheme.secondaryInk)
                Spacer(minLength: 0)
            }
        case .draw:
            drawingControls
        }
    }

    @ViewBuilder
    private var selectionControls: some View {
        if let selection {
            HStack(spacing: 10) {
                Label(selection.label, systemImage: selection.systemImage)
                    .font(.subheadline.weight(.semibold))
                Spacer()

                if case let .text(id) = selection,
                   let edit = textEdits.first(where: { $0.id == id }) {
                    Button("Edit") { beginEditingText(edit) }
                        .buttonStyle(.bordered)
                    Button {
                        duplicateText(edit)
                    } label: {
                        Image(systemName: "plus.square.on.square")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Duplicate text")
                }

                Button(role: .destructive) {
                    deleteSelection(selection)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        } else {
            HStack {
                Label("Select text or a pending redaction to adjust it", systemImage: "hand.tap")
                    .font(.subheadline)
                    .foregroundStyle(ScanTheme.secondaryInk)
                Spacer()
            }
        }
    }

    private var drawingControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    Picker("Drawing Input", selection: drawingInputBinding) {
                        ForEach(EditorDrawingInputMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 330)
                    .accessibilityHint("Choose whether a finger or Apple Pencil creates ink")
                } else {
                    Label("Finger drawing", systemImage: "hand.draw")
                        .font(.subheadline.weight(.semibold))
                }

                Spacer()

                ForEach(DrawingInstrument.allCases) { instrument in
                    Button {
                        selectedInstrument = instrument
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Image(systemName: instrument.systemImage)
                            .frame(width: 42, height: 42)
                            .background(
                                selectedInstrument == instrument ? ScanTheme.accentSoft : Color.clear,
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                            )
                            .foregroundStyle(selectedInstrument == instrument ? ScanTheme.accent : ScanTheme.secondaryInk)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(instrument.title)
                    .accessibilityAddTraits(selectedInstrument == instrument ? .isSelected : [])
                }
            }

            if selectedInstrument != .eraser {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) {
                        inkColorPicker
                        strokeWidthControl
                    }
                    VStack(spacing: 4) {
                        inkColorPicker
                        strokeWidthControl
                    }
                }
            } else {
                HStack {
                    Label("Erase whole strokes by drawing across them", systemImage: "eraser")
                        .font(.footnote)
                        .foregroundStyle(ScanTheme.secondaryInk)
                    Spacer()
                }
            }
        }
    }

    private var inkColorPicker: some View {
        HStack(spacing: 0) {
            ForEach(PageMarkupColor.allCases.filter { $0 != .white }) { color in
                Button {
                    inkColor = color
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Circle()
                        .fill(Color(uiColor: color.uiColor))
                        .frame(width: 24, height: 24)
                        .overlay {
                            Circle()
                                .stroke(
                                    inkColor == color ? ScanTheme.ink : ScanTheme.border,
                                    lineWidth: inkColor == color ? 2 : 1
                                )
                                .padding(-4)
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(color.rawValue.capitalized) ink")
                .accessibilityAddTraits(inkColor == color ? .isSelected : [])
            }
        }
    }

    private var strokeWidthControl: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.diagonal")
                .font(.caption)
            Slider(value: $relativeInkWidth, in: 0.003...0.018)
                .frame(minWidth: 90, maxWidth: 220)
                .accessibilityLabel("Stroke width")
            Image(systemName: "line.diagonal")
                .font(.title3.weight(.bold))
        }
        .foregroundStyle(ScanTheme.secondaryInk)
    }

    private var drawingInputBinding: Binding<EditorDrawingInputMode> {
        Binding(
            get: { drawingInputMode },
            set: { switchDrawingInput(to: $0) }
        )
    }

    private var activePencilTool: any PKTool {
        let canonicalWidth = canonicalCanvasSize.width
        switch selectedInstrument {
        case .pen:
            return PKInkingTool(
                .pen,
                color: inkColor.uiColor,
                width: relativeInkWidth * canonicalWidth
            )
        case .highlighter:
            return PKInkingTool(
                .marker,
                color: inkColor.uiColor,
                width: relativeInkWidth * canonicalWidth * 2.8
            )
        case .eraser:
            return PKEraserTool(.vector)
        }
    }

    private func redactionGesture(in canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .local)
            .updating($draftRedactionFrame) { value, frame, _ in
                frame = normalizedRect(
                    from: value.startLocation,
                    to: value.location,
                    in: canvasSize
                )
            }
            .onEnded { value in
                let frame = normalizedRect(
                    from: value.startLocation,
                    to: value.location,
                    in: canvasSize
                )
                guard frame.width * canvasSize.width >= 8,
                      frame.height * canvasSize.height >= 8 else { return }

                let redaction = PageRedactionEdit(frame: frame)
                performMutation {
                    redactions.append(redaction)
                    selection = .redaction(redaction.id)
                }
                selectedTool = .select
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
    }

    private func prepareNewText(at point: CGPoint) {
        let width: CGFloat = 0.52
        let height: CGFloat = 0.12
        let origin = CGPoint(
            x: min(max(0, point.x - width / 2), 1 - width),
            y: min(max(0, point.y - height / 2), 1 - height)
        )
        textEditorDraft = TextEditorDraft(
            editID: nil,
            text: "",
            frame: CGRect(origin: origin, size: CGSize(width: width, height: height)),
            fontScale: 0.045,
            color: .black,
            isBold: false,
            hasBackground: false
        )
    }

    private func beginEditingText(_ edit: PageTextEdit) {
        textEditorDraft = TextEditorDraft(
            editID: edit.id,
            text: edit.text,
            frame: edit.frame,
            fontScale: edit.fontScale,
            color: edit.color,
            isBold: edit.isBold,
            hasBackground: edit.hasBackground
        )
    }

    private func saveTextEdit(_ draft: TextEditorDraft) {
        let trimmed = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let editID = draft.editID,
           let index = textEdits.firstIndex(where: { $0.id == editID }) {
            performMutation {
                if trimmed.isEmpty {
                    textEdits.remove(at: index)
                    selection = nil
                } else {
                    textEdits[index] = PageTextEdit(
                        id: editID,
                        text: trimmed,
                        frame: draft.frame,
                        fontScale: draft.fontScale,
                        color: draft.color,
                        isBold: draft.isBold,
                        hasBackground: draft.hasBackground
                    )
                    selection = .text(editID)
                }
            }
        } else if !trimmed.isEmpty {
            let edit = PageTextEdit(
                text: trimmed,
                frame: draft.frame,
                fontScale: draft.fontScale,
                color: draft.color,
                isBold: draft.isBold,
                hasBackground: draft.hasBackground
            )
            performMutation {
                textEdits.append(edit)
                selection = .text(edit.id)
            }
        }

        textEditorDraft = nil
        selectedTool = .select
    }

    private func updateTextFrame(id: UUID, frame: CGRect) {
        guard let index = textEdits.firstIndex(where: { $0.id == id }),
              textEdits[index].frame != frame else { return }
        performMutation { textEdits[index].frame = frame }
    }

    private func updateRedactionFrame(id: UUID, frame: CGRect) {
        guard let index = redactions.firstIndex(where: { $0.id == id }),
              redactions[index].frame != frame else { return }
        performMutation { redactions[index].frame = frame }
    }

    private var directManipulationTargets: [CanvasDirectTarget] {
        textEdits.map { CanvasDirectTarget(selection: .text($0.id), frame: $0.frame) }
            + redactions.map { CanvasDirectTarget(selection: .redaction($0.id), frame: $0.frame) }
    }

    private func updateFrameWithoutHistory(_ item: EditorSelection, _ frame: CGRect) {
        switch item {
        case let .text(id):
            guard let index = textEdits.firstIndex(where: { $0.id == id }) else { return }
            textEdits[index].frame = frame
        case let .redaction(id):
            guard let index = redactions.firstIndex(where: { $0.id == id }) else { return }
            redactions[index].frame = frame
        }
    }

    private func duplicateText(_ edit: PageTextEdit) {
        var copy = PageTextEdit(
            text: edit.text,
            frame: edit.frame.offsetBy(dx: 0.035, dy: 0.035).clampedToUnitBounds(),
            fontScale: edit.fontScale,
            color: edit.color,
            isBold: edit.isBold,
            hasBackground: edit.hasBackground
        )
        copy.frame = copy.frame.clampedToUnitBounds()
        performMutation {
            textEdits.append(copy)
            selection = .text(copy.id)
        }
    }

    private func deleteSelection(_ item: EditorSelection) {
        performMutation {
            switch item {
            case let .text(id):
                textEdits.removeAll { $0.id == id }
            case let .redaction(id):
                redactions.removeAll { $0.id == id }
            }
            selection = nil
        }
    }

    private func beginDrawingStroke() {
        guard !isRecordingStroke else { return }
        pushUndoSnapshot()
        isRecordingStroke = true
    }

    private func finishDrawingStroke(_ completedDrawing: PKDrawing) {
        drawing = completedDrawing
        isRecordingStroke = false
    }

    private func activatePencilInput() {
        guard UIDevice.current.userInterfaceIdiom == .pad,
              drawingInputMode != .pencil else { return }
        switchDrawingInput(to: .pencil)
    }

    private func switchDrawingInput(to mode: EditorDrawingInputMode) {
        guard drawingInputMode != mode else { return }
        storedInputMode = mode.rawValue

        let feedback = UISelectionFeedbackGenerator()
        feedback.prepare()
        feedback.selectionChanged()

        let announcement = mode == .pencil
            ? "Apple Pencil active. Touch will move and resize, not draw."
            : "Finger drawing active."
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }

    private func performMutation(_ mutation: () -> Void) {
        pushUndoSnapshot()
        mutation()
    }

    private func pushUndoSnapshot() {
        undoStack.append(currentSnapshot)
        if undoStack.count > 40 {
            undoStack.removeFirst(undoStack.count - 40)
        }
        redoStack.removeAll()
    }

    private var currentSnapshot: EditorSnapshot {
        EditorSnapshot(
            drawingData: drawing.dataRepresentation(),
            textEdits: textEdits,
            redactions: redactions
        )
    }

    private func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        redoStack.append(currentSnapshot)
        restore(snapshot)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func redo() {
        guard let snapshot = redoStack.popLast() else { return }
        undoStack.append(currentSnapshot)
        restore(snapshot)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func restore(_ snapshot: EditorSnapshot) {
        drawing = (try? PKDrawing(data: snapshot.drawingData)) ?? PKDrawing()
        textEdits = snapshot.textEdits
        redactions = snapshot.redactions
        selection = nil
        isRecordingStroke = false
    }

    private func requestSave() {
        if redactions.isEmpty {
            renderAndComplete()
        } else {
            isRedactionConfirmationPresented = true
        }
    }

    private func renderAndComplete() {
        guard !isRendering else { return }
        isRendering = true

        let sourceImage = image
        let drawingData = drawing.dataRepresentation()
        let canvasSize = canonicalCanvasSize
        let pendingTextEdits = textEdits
        let pendingRedactions = redactions

        Task {
            let renderedImage = await Task.detached(priority: .userInitiated) {
                let pendingDrawing = (try? PKDrawing(data: drawingData)) ?? PKDrawing()
                return PageEditRenderer.render(
                    image: sourceImage,
                    drawing: pendingDrawing,
                    drawingCanvasSize: canvasSize,
                    textEdits: pendingTextEdits,
                    redactions: pendingRedactions
                )
            }.value

            onComplete(renderedImage)
        }
    }

    private var redactionConfirmationTitle: String {
        let count = redactions.count
        return "Apply \(count) permanent redaction\(count == 1 ? "" : "s")?"
    }

    private func normalized(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(0, point.x / max(1, size.width)), 1),
            y: min(max(0, point.y / max(1, size.height)), 1)
        )
    }

    private func normalizedRect(from start: CGPoint, to end: CGPoint, in size: CGSize) -> CGRect {
        let first = normalized(start, in: size)
        let second = normalized(end, in: size)
        return CGRect(
            x: min(first.x, second.x),
            y: min(first.y, second.y),
            width: abs(second.x - first.x),
            height: abs(second.y - first.y)
        )
    }

    private func aspectFitSize(imageSize: CGSize, availableSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(
            availableSize.width / imageSize.width,
            availableSize.height / imageSize.height
        )
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}

private enum EditorTool: String, CaseIterable, Identifiable {
    case select
    case text
    case redact
    case draw

    var id: Self { self }

    var title: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .select: "hand.point.up.left"
        case .text: "textformat"
        case .redact: "rectangle.fill"
        case .draw: "scribble.variable"
        }
    }
}

private enum DrawingInstrument: String, CaseIterable, Identifiable {
    case pen
    case highlighter
    case eraser

    var id: Self { self }
    var title: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .pen: "pencil.tip"
        case .highlighter: "highlighter"
        case .eraser: "eraser"
        }
    }
}

private enum EditorSelection: Equatable {
    case text(UUID)
    case redaction(UUID)

    var label: String {
        switch self {
        case .text: "Text box"
        case .redaction: "Pending redaction"
        }
    }

    var systemImage: String {
        switch self {
        case .text: "textformat"
        case .redaction: "lock.fill"
        }
    }
}

private struct CanvasDirectTarget {
    let selection: EditorSelection
    let frame: CGRect
}

private struct EditorSnapshot {
    let drawingData: Data
    let textEdits: [PageTextEdit]
    let redactions: [PageRedactionEdit]
}

private struct TextEditorDraft: Identifiable {
    let id = UUID()
    let editID: UUID?
    var text: String
    var frame: CGRect
    var fontScale: CGFloat
    var color: PageMarkupColor
    var isBold: Bool
    var hasBackground: Bool
}

private struct EditorToolButton: View {
    let tool: EditorTool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            FloatingActionLabel(title: tool.title, systemImage: tool.systemImage, isProminent: isSelected)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct TextEditSheet: View {
    let onCancel: () -> Void
    let onSave: (TextEditorDraft) -> Void

    @State private var draft: TextEditorDraft
    @FocusState private var isTextFocused: Bool

    init(
        draft: TextEditorDraft,
        onCancel: @escaping () -> Void,
        onSave: @escaping (TextEditorDraft) -> Void
    ) {
        _draft = State(initialValue: draft)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Text") {
                    TextEditor(text: $draft.text)
                        .focused($isTextFocused)
                        .frame(minHeight: 92)
                        .font(.body)
                }

                Section("Style") {
                    HStack(spacing: 14) {
                        ForEach(PageMarkupColor.allCases) { color in
                            Button {
                                draft.color = color
                            } label: {
                                Circle()
                                    .fill(Color(uiColor: color.uiColor))
                                    .frame(width: 27, height: 27)
                                    .overlay {
                                        Circle()
                                            .stroke(Color.primary.opacity(0.24), lineWidth: 1)
                                    }
                                    .overlay {
                                        if draft.color == color {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(color == .white || color == .yellow ? .black : .white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(color.rawValue.capitalized)
                            .accessibilityAddTraits(draft.color == color ? .isSelected : [])
                        }
                    }

                    HStack {
                        Image(systemName: "textformat.size.smaller")
                        Slider(value: $draft.fontScale, in: 0.025...0.085)
                            .accessibilityLabel("Text size")
                        Image(systemName: "textformat.size.larger")
                    }

                    Toggle("Bold", isOn: $draft.isBold)
                    Toggle("White background", isOn: $draft.hasBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ScanTheme.background)
            .navigationTitle(draft.editID == nil ? "Add Text" : "Edit Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(draft) }
                        .fontWeight(.semibold)
                        .disabled(draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .tint(ScanTheme.accent)
        .onAppear { isTextFocused = true }
    }
}

private struct TextEditOverlay: View {
    let edit: PageTextEdit
    let canvasSize: CGSize
    let isSelected: Bool
    let isInteractionEnabled: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onMove: (CGRect) -> Void
    let onResize: (CGRect) -> Void
    let onDelete: () -> Void

    @GestureState private var moveTranslation = CGSize.zero

    var body: some View {
        let displayFrame = edit.frame.denormalized(in: canvasSize)

        Text(edit.text)
            .font(.system(
                size: max(9, edit.fontScale * canvasSize.width),
                weight: edit.isBold ? .bold : .regular
            ))
            .foregroundStyle(Color(uiColor: edit.color.uiColor))
            .multilineTextAlignment(.leading)
            .frame(width: displayFrame.width, height: displayFrame.height, alignment: .topLeading)
            .padding(edit.hasBackground ? 3 : 0)
            .background(edit.hasBackground ? Color.white.opacity(0.92) : Color.clear)
            .contentShape(Rectangle())
            .overlay {
                if isSelected {
                    Rectangle().stroke(ScanTheme.accent, lineWidth: 2)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isSelected {
                    ResizeHandle(
                        originalFrame: edit.frame,
                        canvasSize: canvasSize,
                        minimumSize: CGSize(width: 0.16, height: 0.07),
                        onResize: onResize
                    )
                    .offset(x: 12, y: 12)
                }
            }
            .position(
                x: displayFrame.midX + moveTranslation.width,
                y: displayFrame.midY + moveTranslation.height
            )
            .gesture(
                DragGesture(minimumDistance: 2)
                    .updating($moveTranslation) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        onMove(edit.frame.moved(by: value.translation, in: canvasSize))
                    }
            )
            .onTapGesture(count: 2, perform: onEdit)
            .onTapGesture(perform: onSelect)
            .contextMenu {
                Button("Edit Text", action: onEdit)
                Button("Delete", role: .destructive, action: onDelete)
            }
            .allowsHitTesting(isInteractionEnabled)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Text box: \(edit.text)")
            .accessibilityHint("Double tap to select. Use the actions to edit or delete.")
            .accessibilityAction(named: "Edit", onEdit)
            .accessibilityAction(named: "Delete", onDelete)
    }
}

private struct RedactionEditOverlay: View {
    let redaction: PageRedactionEdit
    let canvasSize: CGSize
    let isSelected: Bool
    let isInteractionEnabled: Bool
    let onSelect: () -> Void
    let onMove: (CGRect) -> Void
    let onResize: (CGRect) -> Void
    let onDelete: () -> Void

    @GestureState private var moveTranslation = CGSize.zero

    var body: some View {
        let displayFrame = redaction.frame.denormalized(in: canvasSize)

        Rectangle()
            .fill(Color.black)
            .overlay {
                if isSelected {
                    Rectangle().stroke(ScanTheme.accent, lineWidth: 2)
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.82))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isSelected {
                    ResizeHandle(
                        originalFrame: redaction.frame,
                        canvasSize: canvasSize,
                        minimumSize: CGSize(width: 0.025, height: 0.018),
                        onResize: onResize
                    )
                    .offset(x: 12, y: 12)
                }
            }
            .frame(width: displayFrame.width, height: displayFrame.height)
            .position(
                x: displayFrame.midX + moveTranslation.width,
                y: displayFrame.midY + moveTranslation.height
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .updating($moveTranslation) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        onMove(redaction.frame.moved(by: value.translation, in: canvasSize))
                    }
            )
            .onTapGesture(perform: onSelect)
            .contextMenu {
                Button("Delete Redaction", role: .destructive, action: onDelete)
            }
            .allowsHitTesting(isInteractionEnabled)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Pending permanent redaction")
            .accessibilityHint("Double tap to select, then drag or resize.")
            .accessibilityAction(named: "Delete", onDelete)
    }
}

private struct ResizeHandle: View {
    let originalFrame: CGRect
    let canvasSize: CGSize
    let minimumSize: CGSize
    let onResize: (CGRect) -> Void

    @GestureState private var translation = CGSize.zero

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 18, height: 18)
                .overlay {
                    Circle().stroke(ScanTheme.accent, lineWidth: 3)
                }
        }
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .offset(x: translation.width, y: translation.height)
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .updating($translation) { value, state, _ in state = value.translation }
                .onEnded { value in
                    onResize(originalFrame.resized(
                        by: value.translation,
                        in: canvasSize,
                        minimumSize: minimumSize
                    ))
                }
        )
        .accessibilityLabel("Resize handle")
    }
}

private struct ZoomableEditorPage<Content: View>: UIViewControllerRepresentable {
    let pageSize: CGSize
    let resetID: Int
    @ViewBuilder let content: () -> Content

    func makeUIViewController(context: Context) -> EditorZoomViewController<Content> {
        EditorZoomViewController(content: content(), pageSize: pageSize, resetID: resetID)
    }

    func updateUIViewController(_ controller: EditorZoomViewController<Content>, context: Context) {
        controller.update(content: content(), pageSize: pageSize, resetID: resetID)
    }
}

// Keep the page, ink, and annotations in one coordinate space. Only the viewport
// zooms; drawing data and normalized edit frames remain at their original scale.
final class EditorZoomViewController<Content: View>: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    let scrollView = UIScrollView()
    private let pageContainer = UIView()
    private let hostingController: UIHostingController<Content>
    private var pageSize: CGSize
    private var laidOutPageSize = CGSize.zero
    private var laidOutViewportSize = CGSize.zero
    private var resetID: Int
    private var pinchStartScale: CGFloat = 1
    private var pinchAnchor = CGPoint.zero

    init(content: Content, pageSize: CGSize, resetID: Int) {
        hostingController = UIHostingController(rootView: content)
        self.pageSize = pageSize
        self.resetID = resetID
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        scrollView.backgroundColor = .clear
        scrollView.bouncesZoom = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delaysContentTouches = false
        scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        scrollView.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        view.addSubview(scrollView)

        addChild(hostingController)
        hostingController.view.backgroundColor = .clear
        hostingController.safeAreaRegions = []
        // Keep the viewport transform separate from SwiftUI's page layout.
        pageContainer.frame = CGRect(origin: .zero, size: pageSize)
        scrollView.contentSize = pageSize
        scrollView.addSubview(pageContainer)
        pageContainer.addSubview(hostingController.view)
        hostingController.view.frame = pageContainer.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.didMove(toParent: self)
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.pinchGestureRecognizer?.isEnabled = false

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        pinch.delegate = self
        scrollView.addGestureRecognizer(pinch)
    }

    func update(content: Content, pageSize: CGSize, resetID: Int) {
        hostingController.rootView = content
        self.pageSize = pageSize
        view.setNeedsLayout()
        if self.resetID != resetID {
            self.resetID = resetID
            view.layoutIfNeeded()
            scrollView.setZoomScale(1, animated: false)
            centerPage()
            scrollView.setContentOffset(
                CGPoint(x: -scrollView.contentInset.left, y: -scrollView.contentInset.top),
                animated: false
            )
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let viewportSize = view.bounds.size
        guard viewportSize.width > 0, viewportSize.height > 0,
              pageSize.width > 0, pageSize.height > 0 else { return }

        guard viewportSize != laidOutViewportSize || pageSize != laidOutPageSize else { return }

        let scale = scrollView.zoomScale
        let focalPoint: CGPoint
        if laidOutPageSize.width > 0, laidOutPageSize.height > 0 {
            focalPoint = CGPoint(
                x: (scrollView.contentOffset.x + laidOutViewportSize.width / 2) / (laidOutPageSize.width * scale),
                y: (scrollView.contentOffset.y + laidOutViewportSize.height / 2) / (laidOutPageSize.height * scale)
            )
        } else {
            focalPoint = CGPoint(x: 0.5, y: 0.5)
        }

        laidOutViewportSize = viewportSize
        laidOutPageSize = pageSize
        scrollView.frame = view.bounds
        scrollView.setZoomScale(1, animated: false)
        pageContainer.frame = CGRect(origin: .zero, size: pageSize)
        hostingController.view.frame = pageContainer.bounds
        scrollView.contentSize = pageSize
        scrollView.setZoomScale(scale, animated: false)
        centerPage()

        let inset = scrollView.contentInset
        scrollView.contentOffset = CGPoint(
            x: min(max(focalPoint.x * pageSize.width * scale - viewportSize.width / 2, -inset.left),
                   max(-inset.left, scrollView.contentSize.width - viewportSize.width + inset.right)),
            y: min(max(focalPoint.y * pageSize.height * scale - viewportSize.height / 2, -inset.top),
                   max(-inset.top, scrollView.contentSize.height - viewportSize.height + inset.bottom))
        )
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return pageContainer
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerPage()
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        if recognizer.state == .began {
            pinchStartScale = scrollView.zoomScale
            pinchAnchor = recognizer.location(in: pageContainer)
            // The pinch's moving midpoint already pans the page. Avoid applying
            // the scroll view's two-finger translation a second time.
            scrollView.panGestureRecognizer.isEnabled = false
        }

        switch recognizer.state {
        case .began, .changed:
            zoom(
                to: pinchStartScale * recognizer.scale,
                anchor: pinchAnchor,
                location: recognizer.location(in: view)
            )
        case .ended, .cancelled, .failed:
            scrollView.panGestureRecognizer.isEnabled = true
        default:
            break
        }
    }

    func zoom(to scale: CGFloat, anchor: CGPoint, location: CGPoint) {
        let scale = min(max(scale, scrollView.minimumZoomScale), scrollView.maximumZoomScale)
        scrollView.setZoomScale(scale, animated: false)
        centerPage()
        let inset = scrollView.contentInset
        scrollView.contentOffset = CGPoint(
            x: min(max(anchor.x * scale - location.x, -inset.left),
                   max(-inset.left, scrollView.contentSize.width - scrollView.bounds.width + inset.right)),
            y: min(max(anchor.y * scale - location.y, -inset.top),
                   max(-inset.top, scrollView.contentSize.height - scrollView.bounds.height + inset.bottom))
        )
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        otherGestureRecognizer === scrollView.panGestureRecognizer
    }

    private func centerPage() {
        let horizontal = max(0, (scrollView.bounds.width - pageSize.width * scrollView.zoomScale) / 2)
        let vertical = max(0, (scrollView.bounds.height - pageSize.height * scrollView.zoomScale) / 2)
        scrollView.contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }
}

private struct CanonicalPencilCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    let canonicalSize: CGSize
    let tool: any PKTool
    let drawingPolicy: PKCanvasViewDrawingPolicy
    let isActive: Bool
    let directManipulationTargets: [CanvasDirectTarget]
    let selectedDirectTarget: EditorSelection?
    let allowsDirectManipulation: Bool
    let onStrokeBegan: () -> Void
    let onStrokeEnded: (PKDrawing) -> Void
    let onPencilDetected: () -> Void
    let onDirectSelect: (EditorSelection?) -> Void
    let onDirectManipulationBegan: () -> Void
    let onDirectFrameChanged: (EditorSelection, CGRect) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> CanonicalCanvasContainerView {
        let container = CanonicalCanvasContainerView(canonicalSize: canonicalSize)
        let canvas = container.canvasView
        canvas.delegate = context.coordinator
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.panGestureRecognizer.isEnabled = false
        canvas.pinchGestureRecognizer?.isEnabled = false
        canvas.bounces = false
        canvas.alwaysBounceHorizontal = false
        canvas.alwaysBounceVertical = false

        let pencilRecognizer = PencilContactGestureRecognizer {
            context.coordinator.parent.onPencilDetected()
        }
        pencilRecognizer.cancelsTouchesInView = false
        pencilRecognizer.delegate = context.coordinator
        pencilRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        canvas.addGestureRecognizer(pencilRecognizer)

        let directPan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDirectPan(_:))
        )
        directPan.maximumNumberOfTouches = 1
        directPan.cancelsTouchesInView = false
        directPan.delegate = context.coordinator
        directPan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        canvas.addGestureRecognizer(directPan)
        context.coordinator.directPanRecognizer = directPan

        let directTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDirectTap(_:))
        )
        directTap.cancelsTouchesInView = false
        directTap.delegate = context.coordinator
        directTap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        directTap.require(toFail: directPan)
        canvas.addGestureRecognizer(directTap)
        context.coordinator.directTapRecognizer = directTap

        return container
    }

    func updateUIView(_ container: CanonicalCanvasContainerView, context: Context) {
        context.coordinator.parent = self
        container.canonicalSize = canonicalSize

        let canvas = container.canvasView
        canvas.tool = tool
        canvas.drawingPolicy = drawingPolicy
        canvas.isUserInteractionEnabled = isActive
        context.coordinator.directPanRecognizer?.isEnabled = allowsDirectManipulation
        context.coordinator.directTapRecognizer?.isEnabled = allowsDirectManipulation
        if !allowsDirectManipulation {
            context.coordinator.directInteraction = nil
        }

        let incomingData = drawing.dataRepresentation()
        if canvas.drawing.dataRepresentation() != incomingData {
            context.coordinator.isApplyingExternalDrawing = true
            canvas.drawing = drawing
            context.coordinator.isApplyingExternalDrawing = false
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
        var parent: CanonicalPencilCanvas
        var isApplyingExternalDrawing = false
        weak var directPanRecognizer: UIPanGestureRecognizer?
        weak var directTapRecognizer: UITapGestureRecognizer?
        var directInteraction: DirectInteraction?

        init(parent: CanonicalPencilCanvas) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingExternalDrawing else { return }
            parent.drawing = canvasView.drawing
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            parent.onStrokeBegan()
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            parent.onStrokeEnded(canvasView.drawing)
        }

        @objc func handleDirectTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  let canvas = recognizer.view else { return }
            let point = normalized(recognizer.location(in: canvas))
            parent.onDirectSelect(hitTarget(at: point)?.selection)
        }

        @objc func handleDirectPan(_ recognizer: UIPanGestureRecognizer) {
            guard let canvas = recognizer.view else { return }

            switch recognizer.state {
            case .began:
                let point = normalized(recognizer.location(in: canvas))
                guard let target = hitTarget(at: point) else { return }

                let operation: DirectInteraction.Operation
                if target.selection == parent.selectedDirectTarget,
                   resizeHandleRect(for: target.frame).contains(point) {
                    operation = .resize
                } else {
                    operation = .move
                }

                directInteraction = DirectInteraction(
                    target: target.selection,
                    originalFrame: target.frame,
                    operation: operation
                )
                parent.onDirectSelect(target.selection)
                parent.onDirectManipulationBegan()

            case .changed, .ended:
                guard let interaction = directInteraction else { return }
                let translatedPoint = recognizer.translation(in: canvas)
                let translation = CGSize(
                    width: translatedPoint.x,
                    height: translatedPoint.y
                )
                let updatedFrame: CGRect

                switch interaction.operation {
                case .move:
                    updatedFrame = interaction.originalFrame.moved(
                        by: translation,
                        in: parent.canonicalSize
                    )
                case .resize:
                    let minimumSize: CGSize
                    switch interaction.target {
                    case .text:
                        minimumSize = CGSize(width: 0.16, height: 0.07)
                    case .redaction:
                        minimumSize = CGSize(width: 0.025, height: 0.018)
                    }
                    updatedFrame = interaction.originalFrame.resized(
                        by: translation,
                        in: parent.canonicalSize,
                        minimumSize: minimumSize
                    )
                }

                parent.onDirectFrameChanged(interaction.target, updatedFrame)
                if recognizer.state == .ended { directInteraction = nil }

            case .cancelled, .failed:
                if let interaction = directInteraction {
                    parent.onDirectFrameChanged(interaction.target, interaction.originalFrame)
                }
                directInteraction = nil

            default:
                break
            }
        }

        private func normalized(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: min(max(0, point.x / max(1, parent.canonicalSize.width)), 1),
                y: min(max(0, point.y / max(1, parent.canonicalSize.height)), 1)
            )
        }

        private func hitTarget(at point: CGPoint) -> CanvasDirectTarget? {
            if let selection = parent.selectedDirectTarget,
               let selected = parent.directManipulationTargets.first(where: {
                   $0.selection == selection
               }),
               (resizeHandleRect(for: selected.frame).contains(point)
                    || selected.frame.contains(point)) {
                return selected
            }

            return parent.directManipulationTargets.reversed().first {
                $0.frame.contains(point)
            }
        }

        private func resizeHandleRect(for frame: CGRect) -> CGRect {
            let displaySize = directPanRecognizer?.view?.superview?.bounds.size ?? parent.canonicalSize
            let halfWidth = 24 / max(1, displaySize.width)
            let halfHeight = 24 / max(1, displaySize.height)
            return CGRect(
                x: frame.maxX - halfWidth,
                y: frame.maxY - halfHeight,
                width: halfWidth * 2,
                height: halfHeight * 2
            )
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        struct DirectInteraction {
            enum Operation {
                case move
                case resize
            }

            let target: EditorSelection
            let originalFrame: CGRect
            let operation: Operation
        }
    }
}

private final class CanonicalCanvasContainerView: UIView {
    let canvasView = PKCanvasView()
    var canonicalSize: CGSize {
        didSet { setNeedsLayout() }
    }

    init(canonicalSize: CGSize) {
        self.canonicalSize = canonicalSize
        super.init(frame: .zero)
        clipsToBounds = true
        backgroundColor = .clear
        addSubview(canvasView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard canonicalSize.width > 0, canonicalSize.height > 0 else { return }

        canvasView.transform = .identity
        canvasView.bounds = CGRect(origin: .zero, size: canonicalSize)
        canvasView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        canvasView.transform = CGAffineTransform(
            scaleX: bounds.width / canonicalSize.width,
            y: bounds.height / canonicalSize.height
        )
    }
}

private final class PencilContactGestureRecognizer: UIGestureRecognizer {
    private let onPencilContact: () -> Void

    init(onPencilContact: @escaping () -> Void) {
        self.onPencilContact = onPencilContact
        super.init(target: nil, action: nil)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard touches.contains(where: { $0.type == .pencil }) else {
            state = .failed
            return
        }
        onPencilContact()
        state = .began
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .began || state == .changed { state = .changed }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .began || state == .changed { state = .ended }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
    }
}

private extension CGRect {
    func denormalized(in size: CGSize) -> CGRect {
        CGRect(
            x: minX * size.width,
            y: minY * size.height,
            width: width * size.width,
            height: height * size.height
        )
    }

    func moved(by translation: CGSize, in canvasSize: CGSize) -> CGRect {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return self }
        return offsetBy(
            dx: translation.width / canvasSize.width,
            dy: translation.height / canvasSize.height
        ).clampedToUnitBounds()
    }

    func resized(by translation: CGSize, in canvasSize: CGSize, minimumSize: CGSize) -> CGRect {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return self }
        let newWidth = min(
            max(minimumSize.width, width + translation.width / canvasSize.width),
            1 - minX
        )
        let newHeight = min(
            max(minimumSize.height, height + translation.height / canvasSize.height),
            1 - minY
        )
        return CGRect(x: minX, y: minY, width: newWidth, height: newHeight)
    }

    func clampedToUnitBounds() -> CGRect {
        let safeWidth = min(max(0, width), 1)
        let safeHeight = min(max(0, height), 1)
        return CGRect(
            x: min(max(0, minX), 1 - safeWidth),
            y: min(max(0, minY), 1 - safeHeight),
            width: safeWidth,
            height: safeHeight
        )
    }
}
