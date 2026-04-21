# NewsBit

NewsBit is an iOS news app built with SwiftUI.

It lets users create an account, read news, save stories, comment on posts, follow other users, and send messages. The app also has profile customization, highlighted stories, and search for both news and users.

## What This App Can Do

- Create an account and log in
- Log in with email or username
- Read news by category
- Open the full news details page
- Save stories to favorites
- Highlight stories on a user profile
- Add comments and replies
- Upvote and downvote comments
- Search news
- Search users
- Follow other users
- Send direct messages
- Share a news story in chat
- Upload a profile photo and cover photo
- Change avatar color

## Built With

- SwiftUI
- Firebase Authentication
- Cloud Firestore
- PhotosUI
- News API from `https://newsbitapi.onrender.com`

## Project Structure

- `NewsBit/` - main app source code
- `NewsBit.xcodeproj/` - Xcode project
- `images/` - UI screenshots used in this README

## Main App Areas

- `AuthViews.swift` - login and register screens
- `AuthViewModel.swift` - sign in, register, session restore, and profile loading
- `HomeView.swift` - news feed, story details, comments, and share flow
- `FavoritesView.swift` - saved stories
- `MessagesView.swift` - inbox, chat, and story sharing in messages
- `SearchView.swift` - search news and users
- `ProfileView.swift` - own profile, avatar, and cover image
- `VisitedUserProfileView.swift` - other user profile, follow, message, and highlights
- `NewsFeedService.swift` - feed API calls, categories, and story loading

## How To Run

1. Open `NewsBit.xcodeproj` in Xcode.
2. Wait for Xcode to download the Swift packages.
3. Make sure `NewsBit/GoogleService-Info.plist` matches your Firebase project.
4. In Firebase, turn on Email/Password sign-in.
5. Make sure Firestore is created and ready to use.
6. Choose an iPhone simulator or a real device.
7. Press Run.

## Backend Notes

This app uses Firebase for:

- user login
- user profile data
- favorites
- highlights
- follows
- comments and replies
- direct messages

This app uses the NewsBit API for:

- news feed
- category list
- full story details

If you change the bundle ID, you will also need a new `GoogleService-Info.plist` file from the matching Firebase iOS app.

## Screenshots

### Login And Register

<p align="center">
  <img src="images/login.png" alt="Login screen" width="240" />
  <img src="images/register.png" alt="Register screen" width="240" />
</p>

### News Feed And Reading

<p align="center">
  <img src="images/news_home.png" alt="News home screen" width="240" />
  <img src="images/news_details.png" alt="News details screen" width="240" />
  <img src="images/news_details_2.png" alt="More news details screen" width="240" />
</p>

### Comments, Favorites, And Navigation

<p align="center">
  <img src="images/comment.jpeg" alt="Comments screen" width="240" />
  <img src="images/favourites.png" alt="Favorites screen" width="240" />
  <img src="images/navbar.jpeg" alt="Bottom navigation bar" width="240" />
</p>

### Messages And Search

<p align="center">
  <img src="images/message_inbox.jpeg" alt="Messages inbox screen" width="240" />
  <img src="images/user_search.jpeg" alt="User search screen" width="240" />
</p>

### Profile Screens

<p align="center">
  <img src="images/user_profile.jpeg" alt="Profile screen" width="240" />
  <img src="images/user_profile_2.jpeg" alt="Profile details screen" width="240" />
  <img src="images/user_profile_3.jpeg" alt="More profile screen details" width="240" />
</p>

### User Highlights

<p align="center">
  <img src="images/user_profile_4_highlights.jpeg" alt="User highlights screen" width="240" />
</p>

## Summary

NewsBit is a social news reading app for iPhone. It mixes reading, saving, commenting, following, and messaging in one place.
