import Foundation
import UIKit

@MainActor
final class ScanLibrary: ObservableObject {
    @Published private(set) var documents: [ScanSession] = []
    @Published var storageError: String?

    private let store: ScanDocumentStore

    init(store: ScanDocumentStore = ScanDocumentStore()) {
        self.store = store

        do {
            documents = try store.loadAll().map { snapshot in
                ScanSession(
                    id: snapshot.id,
                    title: snapshot.title,
                    createdAt: snapshot.createdAt,
                    modifiedAt: snapshot.modifiedAt,
                    pages: snapshot.pages
                )
            }
            sortDocuments()
            documents.forEach { document in
                bind(document)
                document.resumePendingAnalysis()
            }
        } catch {
            storageError = error.localizedDescription
        }
    }

    func document(withID id: UUID) -> ScanSession? {
        documents.first { $0.id == id }
    }

    @discardableResult
    func createDocument(with images: [UIImage], title: String? = nil) -> ScanSession {
        let now = Date()
        let importedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let document = ScanSession(
            title: importedTitle.flatMap { $0.isEmpty ? nil : $0 }
                ?? "Scan \(now.formatted(date: .abbreviated, time: .shortened))",
            createdAt: now,
            modifiedAt: now
        )
        bind(document)
        documents.insert(document, at: 0)
        document.add(images)
        return document
    }

    func delete(documentID: UUID) {
        guard documents.contains(where: { $0.id == documentID }) else { return }
        documents.removeAll { $0.id == documentID }

        do {
            try store.delete(documentID: documentID)
        } catch {
            storageError = error.localizedDescription
        }
    }

    private func bind(_ document: ScanSession) {
        document.setChangeHandler { [weak self] changedDocument, forceImageIDs in
            guard let self,
                  self.documents.contains(where: { $0.id == changedDocument.id }) else { return }
            self.persist(changedDocument, forceImageIDs: forceImageIDs)
            self.sortDocuments()
        }
    }

    private func persist(_ document: ScanSession, forceImageIDs: Set<UUID>) {
        do {
            try store.save(
                ScanDocumentSnapshot(
                    id: document.id,
                    title: document.title,
                    createdAt: document.createdAt,
                    modifiedAt: document.modifiedAt,
                    pages: document.pages
                ),
                forceImageIDs: forceImageIDs
            )
        } catch {
            storageError = error.localizedDescription
        }
    }

    private func sortDocuments() {
        documents.sort { $0.modifiedAt > $1.modifiedAt }
    }
}
