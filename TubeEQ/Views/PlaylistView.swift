import SwiftUI

public struct MediaBookmark: Identifiable, Codable, Equatable {
    public var id = UUID()
    public var title: String
    public var urlString: String
}

public struct PlaylistView: View {
    @AppStorage("saved_bookmarks") private var savedBookmarksData: Data = Data()
    @State private var bookmarks: [MediaBookmark] = []
    @State private var newTitle: String = ""
    @State private var newUrl: String = ""
    @State private var showingAddSheet: Bool = false
    var onSelectUrl: (String) -> Void = { _ in }

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()

                List {
                    if bookmarks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("No Saved Playlists or Bookmarks")
                                .foregroundColor(.gray)
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(bookmarks) { item in
                            Button(action: {
                                onSelectUrl(item.urlString)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text(item.urlString)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "play.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.cyan)
                                }
                            }
                            .listRowBackground(Color(white: 0.14))
                        }
                        .onDelete(perform: deleteBookmarks)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Playlists & Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.cyan)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                addBookmarkSheet
            }
            .onAppear(perform: loadBookmarks)
        }
    }

    private var addBookmarkSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Details").foregroundColor(.gray)) {
                    TextField("Title", text: $newTitle)
                    TextField("URL", text: $newUrl)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }
            }
            .navigationTitle("Add Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showingAddSheet = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if !newTitle.isEmpty && !newUrl.isEmpty {
                            bookmarks.append(MediaBookmark(title: newTitle, urlString: newUrl))
                            saveBookmarks()
                            newTitle = ""
                            newUrl = ""
                            showingAddSheet = false
                        }
                    }
                    .disabled(newTitle.isEmpty || newUrl.isEmpty)
                }
            }
        }
    }

    private func deleteBookmarks(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
        saveBookmarks()
    }

    private func loadBookmarks() {
        if let decoded = try? JSONDecoder().decode([MediaBookmark].self, from: savedBookmarksData) {
            bookmarks = decoded
        } else {
            // Default samples
            bookmarks = [
                MediaBookmark(title: "YouTube Music", urlString: "https://music.youtube.com"),
                MediaBookmark(title: "SoundCloud", urlString: "https://soundcloud.com")
            ]
            saveBookmarks()
        }
    }

    private func saveBookmarks() {
        if let encoded = try? JSONEncoder().encode(bookmarks) {
            savedBookmarksData = encoded
        }
    }
}
