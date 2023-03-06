//
//  ChatLogView.swift
//  ChatApp
//
//  Created by Mohit Tiwari.
//

import SwiftUI
import Firebase
import FirebaseStorage


struct FirebaseConstants{
    static let fromId = "fromId"
    static let toId = "toId"
    static let text = "text"
    static let email = "email"
    static let profileImageUrl = "profileImageUrl"
    
}


struct ChatMessage: Identifiable{
    
    var id:String { documentId }
    
    let documentId: String
    let fromId, toId, text:String
    
    init(documentId:String, data: [String:Any]){
        self.documentId = documentId
        self.fromId = data[FirebaseConstants.fromId] as? String ?? ""
        self.toId = data[FirebaseConstants.toId] as? String ?? ""
        self.text = data[FirebaseConstants.text] as? String ?? ""
    }
}

class ChatLogViewModel: ObservableObject{
    
    @Published var chatText = ""
    @Published var errorMessage = ""
    @Published var chatMessages = [ChatMessage]()
    @Published var count = 0
    let chatUser: ChatUser?
    
    init(chatUser: ChatUser){
        self.chatUser = chatUser
        fetchMessages()
    }
    
    func fetchMessages(){
        
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        
        FirebaseManager.shared.firestore
            .collection("messages")
            .document(fromId)
            .collection(toId)
            .order(by: "timestamp")
            .addSnapshotListener { querySnapshot, error in
                
                if let error = error{
                    self.errorMessage = "Failed to listen for messages: \(error)"
                    print(error)
                    return
                }
                
                querySnapshot?.documentChanges.forEach({ change in
                    
                    if change.type == .added{
                        let data = change.document.data()
                        let chatMessage = ChatMessage(documentId: change.document.documentID,data: data)
                        self.chatMessages.append(chatMessage)
                    }
                })
                
                DispatchQueue.main.async{
                    self.count += 1
                }
            }
    }
    
    func handleSend(){
        print(chatText)
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        
        let document = FirebaseManager.shared.firestore.collection("messages")
            .document(fromId)
            .collection(toId)
            .document()
        
        let messageData = [FirebaseConstants.fromId:fromId, FirebaseConstants.toId:toId, FirebaseConstants.text: self.chatText, "timestamp": Timestamp()] as [String : Any]
        
        document.setData(messageData) { error in
            if let error = error{
                self.errorMessage = "Failed to save message into Firestore: \(error)"
            }
            
            print("Successfully saved current user sending message.")
            
            self.persistRecentMessage()
            
            self.chatText = ""
            
        }
        
        let recipientMessageDocument = FirebaseManager.shared.firestore.collection("messages")
            .document(toId)
            .collection(fromId)
            .document()
        
        recipientMessageDocument.setData(messageData) { error in
            if let error = error{
                self.errorMessage = "Failed to save message into Firestore: \(error)"
            }
            print("receipent saved message")
        }
        
        
    }
    
    private func persistRecentMessage(){
        
        guard let chatUser = chatUser else { return }
        
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = self.chatUser?.uid else { return }
        
        let document = FirebaseManager.shared.firestore
            .collection("recent_messages")
            .document(uid)
            .collection("messages")
            .document(toId)
        
        let data: [String:Any] = [
            "timestamp": Timestamp(),
            FirebaseConstants.text: self.chatText,
            FirebaseConstants.fromId: uid,
            FirebaseConstants.toId: toId,
            FirebaseConstants.profileImageUrl: chatUser.profileImageUrl,
            FirebaseConstants.email: chatUser.email
        ]
        
        document.setData(data) { error in
            if let error = error{
                self.errorMessage = "Failed to save recent message: \(error)"
                print("Failed to save recent message: \(error)")
                return
            }
            
        }
        
    }
}


struct ChatLogView: View{
    
    let chatUser: ChatUser?
    @ObservedObject var vm: ChatLogViewModel
   
    init(chatUser: ChatUser){
        self.chatUser = chatUser
        self.vm = .init(chatUser: chatUser)
    }
    
    var body: some View{

        ZStack{
            messagesView
            Text(vm.errorMessage)
        }
        .navigationTitle(chatUser?.email ?? "")
            .navigationBarTitleDisplayMode(.inline)
           
    }
    
    private var messagesView: some View{
        ScrollView{
            ScrollViewReader{ scrollViewProxy in

                VStack{
                    ForEach(vm.chatMessages){ message in
                        MessageView(message:message)
                    }
                    HStack{ Spacer() }
                        .id("Empty")
                }
                .onReceive(vm.$count) { _ in
                    withAnimation(.easeOut(duration: 0.5)){
                        scrollViewProxy.scrollTo("Empty",anchor: .bottom)
                    }
                }
            }
        }
        .background(Color(.init(white: 0.9, alpha: 1)))
        .safeAreaInset(edge: .bottom) {
            chatBottomBar
                .background(Color(.systemBackground))
        }
    }
    
    private var chatBottomBar: some View{
        
        HStack(spacing:16){
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 24))
                .foregroundColor(Color(.darkGray))
//                TextEditor(text: $chatText)
            
            ZStack{
                DescriptionPlaceholder()
                TextEditor(text: $vm.chatText)
                    .opacity(vm.chatText.isEmpty ? 0.5 : 1)
            }
            .frame(height: 40)
            
           
           
            Button {
                vm.handleSend()
            } label: {
                Text("Send")
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            .padding(.vertical,8)
            .background(Color.blue)
            .cornerRadius(5)
            

        }
        .padding(.horizontal)
        .padding(.vertical,8)
        
    }
}


struct MessageView: View{
    
    let message: ChatMessage
    
    var body: some View{
        VStack{
            if message.fromId == FirebaseManager.shared.auth.currentUser?.uid{
                
                HStack{
                    Spacer()
                    HStack{
                        Text(message.text)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }else{
                HStack{
                    HStack{
                        Text(message.text)
                            .foregroundColor(.black)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.top,8)
    }
}

private struct DescriptionPlaceholder: View {
    var body: some View {
        HStack {
            Text("Description")
                .foregroundColor(Color(.gray))
                .font(.system(size: 17))
                .padding(.leading, 5)
                .padding(.top, -4)
            Spacer()
        }
    }
}


struct ChatLogView_Previews: PreviewProvider {
    static var previews: some View {
//        NavigationView{
//            ChatLogView(chatUser: .init(data: ["uid" : "byrnqFktyIMbd8nFzWo7c4piMYD3","email": "nature@gmail.com"]))
//        }
        
        MainMessagesView()
        
    }
}
