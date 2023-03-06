//
//  MainMessagesView.swift
//  ChatApp
//
//  Created by Mohit Tiwari.
//

import SwiftUI
import SDWebImageSwiftUI
import Firebase

struct RecentMessages: Identifiable{
    
    var id: String { documentId }
    
    let documentId: String
    let text, fromId, toId: String
    let email, profileImageUrl: String
    let timestamp: Timestamp
    
    init(documentId: String, data:[String:Any]){
        self.documentId = documentId
        self.text = data["text"] as? String ?? ""
        self.fromId = data["fromId"] as? String ?? ""
        self.toId = data["toId"] as? String ?? ""
        self.email = data["email"] as? String ?? ""
        self.profileImageUrl = data["profileImageUrl"] as? String ?? ""
        self.timestamp = data["timestamp"] as? Timestamp ?? Timestamp(date: Date())
    }
}


class MainMessagesViewModel: ObservableObject {
    
    @Published var errorMessage = ""
    @Published var chatUser: ChatUser?
    @Published var recentMessages = [RecentMessages]()
    @Published var isUserCurrentlyLoggedOut = false
    
    init(){
        
        DispatchQueue.main.async {
            self.isUserCurrentlyLoggedOut = FirebaseManager.shared.auth.currentUser?.uid == nil
        }
        fetchCurrentUser()
        fetchRecentMessages()
    }
    
    
    private func fetchRecentMessages(){
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        
        FirebaseManager.shared.firestore
            .collection("recent_messages")
            .document(uid)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { querySnapshot, error in
                
                if let error = error{
                    self.errorMessage = "failed to listen to recent messages \(error)"
                    print(error)
                    return
                }
                
                querySnapshot?.documentChanges.forEach({ change in
                    let docId = change.document.documentID
                    if let index = self.recentMessages.firstIndex(where: { rm in
                        return rm.documentId == docId
                    }){
                        self.recentMessages.remove(at: index)
                    }
                    
                    self.recentMessages.insert(.init(documentId: docId, data: change.document.data()), at: 0)
                })
            }
    }
    
     func fetchCurrentUser(){
        
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid
            else {
            self.errorMessage = "Could not find firebase uid"
            return
        }
        
        FirebaseManager.shared.firestore.collection("users").document(uid).getDocument { snapshot, error in
            
            if let error = error {
                print(">>>>>>>Failed to fetch current user",error)
                return
            }
            
            guard let data = snapshot?.data() else {return}
            print(data)
            
            self.chatUser = .init(data: data)
           
            
//            self.errorMessage = chatUser.profileImageUrl
        }
        
    }
    
    func handleSignOut(){
        isUserCurrentlyLoggedOut.toggle()
        try? FirebaseManager.shared.auth.signOut()
        
    }
    
}

struct MainMessagesView: View {
    
    @State var shouldShowLogOutOptions = false
    @State var shouldShowNewMessageScreen = false
    @State var shouldNavigateToChatLogView = false
    @State var chatUser: ChatUser?
    @ObservedObject private var vm = MainMessagesViewModel()
    
    var customNavBar: some View{
        //custom nav bar
        HStack(spacing:16){
            
            WebImage(url: URL(string: vm.chatUser?.profileImageUrl ?? ""))
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipped()
                .cornerRadius(44)
                .overlay(RoundedRectangle(cornerRadius: 44)
                    .stroke(Color(.label),lineWidth: 1))
                .shadow(radius: 5)
            
//            Image(systemName: "person.fill")
//                .font(.system(size: 34,weight: .heavy))
//
            VStack(alignment: .leading,spacing: 4){
                Text("\(vm.chatUser?.email.replacingOccurrences(of: "@gmail.com", with: "") ?? "")")
                    .font(.system(size: 25,weight: .bold))
                HStack{
                    Circle()
                        .foregroundColor(.green)
                        .frame(width: 14, height: 14)
                    Text("Online")
                        .font(.system(size: 12))
                        .foregroundColor(Color(.lightGray))
                }
            }
            
            Spacer()
            Button {
                shouldShowLogOutOptions.toggle()
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 24,weight: .bold))
                    .foregroundColor(Color(.label))
            }

            
        }.padding()
            .actionSheet(isPresented: $shouldShowLogOutOptions) {
                .init(title: Text("Settings"),message: Text("What do you want to do?"),buttons: [
                    .destructive(Text("Sign Out"),action: {
                        print("handle sign out")
                        vm.handleSignOut()
                    }),
                    .cancel()
                ])
            }
            .fullScreenCover(isPresented: $vm.isUserCurrentlyLoggedOut, onDismiss: nil) {
                LoginView {
                    self.vm.isUserCurrentlyLoggedOut = false
                    self.vm.fetchCurrentUser()
                }
            }

    }

    
    var body: some View {
        NavigationView{
            VStack{
                customNavBar
                messageView
                
                NavigationLink("", isActive: $shouldNavigateToChatLogView) {
                    if let chatUser = self.chatUser{
                        ChatLogView(chatUser: chatUser)
                    }
                }
            }
            .overlay(
                newMessageButton,alignment: .bottom
            )
            .navigationBarHidden(true)
        }
    }
    
    private var messageView: some View{
        ScrollView{
            ForEach(vm.recentMessages){ recentMessage in
                VStack{
                    
                    NavigationLink {
                        Text("destination")
                    } label: {
                        
                        HStack(spacing: 16){
                            
                            WebImage(url: URL(string: recentMessage.profileImageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipped()
                                .cornerRadius(64)
                                .overlay(RoundedRectangle(cornerRadius: 44)
                                    .stroke(Color(.label),lineWidth: 1))
                            
//                            Image(systemName: "person.fill")
//                                .font(.system(size: 32))
//                                .padding(8)
//                                .overlay(RoundedRectangle(cornerRadius: 44)
//                                    .stroke(Color(.label),lineWidth: 1))
                    }

                    
                   
                        VStack(alignment: .leading,spacing: 8){
                            Text(recentMessage.email)
                                .font(.system(size: 16,weight: .bold))
                                .foregroundColor(Color(.label))
                                
                            Text(recentMessage.text)
                                .font(.system(size: 14))
                                .foregroundColor(Color(.darkGray))
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Text("22d")
                            .font(.system(size: 14,weight: .semibold))
                    }
                    
                }
                Divider()
                    .padding(.vertical,8)
            }.padding(.horizontal)
            
            
        }
        .padding(.bottom,50)

    }
    
    private var newMessageButton: some View{
        Button {
            shouldShowNewMessageScreen.toggle()
        } label: {
            HStack{
                Spacer()
                Text("+ New Message")
                    .font(.system(size: 16,weight: .bold))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.vertical)
            .background(Color.blue)
            .cornerRadius(32)
            .padding(.horizontal)
            .shadow(radius: 15)
        }
        .fullScreenCover(isPresented: $shouldShowNewMessageScreen, onDismiss: nil) {
            CreateNewMessageView { user in
                print(user.email)
                self.shouldNavigateToChatLogView.toggle()
                self.chatUser = user
            }
        }
    }
}




struct MainMessagesView_Previews: PreviewProvider {
    static var previews: some View {
        MainMessagesView()
    }
}
