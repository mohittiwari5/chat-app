//
//  ContentView.swift
//  ChatApp
//
//  Created by Mohit Tiwari.
//

import SwiftUI
import Firebase
import FirebaseStorage


struct LoginView: View {
    
    let didCompleteLoginProcess: () -> ()
    
    @State private var isLoginMode = false
    @State private var email = ""
    @State private var password = ""
    @State private var loginStatusMessage = ""
    @State private var shouldShowImagePicker = false
    
   
    
    var body: some View {
        NavigationView{
            ScrollView{
                VStack(spacing: 20) {
                    Picker(selection: $isLoginMode) {
                        Text("Login")
                            .tag(true)
                        Text("Create Account")
                            .tag(false)
                    } label: {
                        Text("Picker")
                }.pickerStyle(SegmentedPickerStyle())
                
                if !isLoginMode{
                    Button {
                        shouldShowImagePicker.toggle()
                        
                    } label: {
                        
                        VStack{
                            if let image = self.image{
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 128, height: 128)
                                    .cornerRadius(64)
                            }else{
                                Image(systemName: "person.fill")
                                    .font(.system(size: 64))
                                    .padding()
                                    .foregroundColor(Color(.label))
                            }
                        }
                        .overlay(RoundedRectangle(cornerRadius: 64)
                            .stroke(Color.black,lineWidth: 3))
                        
                    }
                }
                    
                
                Group{
                    TextField("Email",text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            
                    SecureField("Password",text: $password)
                            
                }
                .padding(12)
                .background(.white)
                

                
                
                Button {
                    handleAction()
                    
                } label: {
                    HStack{
                        Spacer()
                        Text(isLoginMode ? "Log In" : "Create Account")
                            .foregroundColor(.white)
                            .padding(.vertical,10)
                            .font(.system(size: 14,weight: .semibold))
                        Spacer()
                    }.background(Color.blue)
                }
                    
                    Text(self.loginStatusMessage)
                        .foregroundColor(.red)
            }
                .padding()
                

            }
            .navigationTitle(isLoginMode ? "Log In" : "Create Account")
            .background(Color(.init(white: 0, alpha: 0.05)).ignoresSafeArea())
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .fullScreenCover(isPresented: $shouldShowImagePicker, onDismiss: nil) {
            ImagePicker(image: $image)
        }
    }
    
    @State var image: UIImage?
    private func handleAction(){
        if isLoginMode{
            loginUser()
            print("should log in into firebase")
        }else{
            createNewAcount()
            print("register new account in firebase")
        }
        
    }
    
    
    private func loginUser(){
        FirebaseManager.shared.auth.signIn(withEmail: email, password: password) { result, error in
            if let err = error{
                print(">>>>>>>>>>>>>>>>>>>>>Error login user",err)
                self.loginStatusMessage = "Error login user \(err)"
                return
            }
            
            print(">>>>>>>>>>>>>>>>>>>>>>>>Successfully login user:: \(result?.user.uid ?? "")")
            self.loginStatusMessage = "Successfully login user:: \(result?.user.uid ?? "")"
            
            self.didCompleteLoginProcess()
        }
        
    }
    
    
    private func createNewAcount(){
        
        if self.image == nil{
            self.loginStatusMessage = "You must select an avatar image."
            return
        }
        
        FirebaseManager.shared.auth.createUser(withEmail: email, password: password) { result, error in
            if let err = error{
                print(">>>>>>>>>>>>>>>>>>>>>Error creating new user",err)
                self.loginStatusMessage = "Error creating new user \(err)"
                return
            }
            
            self.loginStatusMessage = "Successfully created user:: \(result?.user.uid ?? "")"
            self.persistImageToStorage()
            
        }
    }
    
    private func persistImageToStorage(){
//        let filename = UUID().uuidString
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid
                else{return}
        let ref = FirebaseManager.shared.storage.reference(withPath: uid)
        guard let imageData = self.image?.jpegData(compressionQuality: 0.5) else {return}
        ref.putData(imageData, metadata: nil) { metadata, error in
            
            if let err = error{
                self.loginStatusMessage = "Failed to upload image to firebase \(err)"
                return
            }
            
            ref.downloadURL { url, error in
                if let err = error{
                    self.loginStatusMessage = "Failed to reterive download url \(err)"
                    return
                }
                
                self.loginStatusMessage = "Successfully stored image with url: \(url?.absoluteString ?? "")"
                
                guard let url = url else {return}
                self.storeUserInformation(imageProfileUrl:url)
                
            }
            
            
        }
        
    }
    
    private func storeUserInformation(imageProfileUrl:URL){
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {return}
        let userData = ["email":self.email,"uid":uid, "profileImageUrl":imageProfileUrl.absoluteString]
        FirebaseManager.shared.firestore.collection("users")
            .document(uid).setData(userData) { err in
                print(err ?? "")
                self.loginStatusMessage = "\(String(describing: err))"
                return
            }
        
        print("Success")
        self.didCompleteLoginProcess()
        
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView {
            
        }
    }
}
