/*
 * code for handling login/logout/signup.
 
 Needs to be updated to capture users email in the login form, and create a 
 profile object and save it with the user. Then I think I might be able to 
 just use the Userbase admin panel? to update a field like "authorized=true"
 that starts out as false. 
 The login checks in various places in the code will need to be enhanced to
 also check for authorized==true, rather than just user exists.  
*/


function changeButton() {
  var x = document.querySelector("#LoginButton");
  if (x.value == "Show Login") {
    x.value = "Hide Login";
  } else {
    x.value = "Show Login";
  }
}


function handleSignUp(e) {
  e.preventDefault()

  const username = document.getElementById('signup-username').value
  const password = document.getElementById('signup-password').value
  const email = document.getElementById('signup-email').value

  userbase.signUp({ username, password, email, rememberMe: 'local' })
    .then((user) => showUserLoggedIn(user.username))
    .catch((e) => document.getElementById('signup-error').innerHTML = e)
}

function handleLogin(e) {
  e.preventDefault()

  const username = document.getElementById('login-username').value
  const password = document.getElementById('login-password').value

  userbase.signIn({ username, password, rememberMe: 'local' })
    .then((user) => showUserLoggedIn(user.username))
    .catch((e) => document.getElementById('login-error').innerHTML = e)
}

function showUserLoggedIn(username) {
  var msg = 'showUserLoggedIn(' + username + ')'
  console.log(msg)
  document.getElementById('auth-view').style.display = 'none'
  document.getElementById('album-content').style.display = 'block';
  document.getElementById('LoggedInUser').style.display = 'block';
  document.getElementById('LoggedInUser').innerHTML = "logged in as <a href=\"#\" title=\"click to log out\">" + username + "</a>";
}

function handleLogout() {
  console.log('handleLogout')
  userbase.signOut()
    .then(() => resetAuthFields())
    .catch((e) => document.getElementById('logout-error').innerText = e)
  
  document.getElementById('auth-view').style.display = 'block'
  document.getElementById('album-content').style.display = 'none';
}

function resetAuthFields() {
  console.log('resetAuthFields')
  
  if (document.getElementById('login-username') != null) {
    document.getElementById('auth-view').style.display = 'block'
    document.getElementById('login-username').value = ''
    document.getElementById('login-password').value = ''
    document.getElementById('login-error').innerText = ''
    document.getElementById('signup-username').value = ''
    document.getElementById('signup-password').value = ''
    document.getElementById('signup-email').value = ''
    document.getElementById('signup-error').innerText = ''
    document.getElementById('LoggedInUser').innerText = ''
    document.getElementById('LoginButton').style.display = 'block'
    document.getElementById('LoggedInUser').style.display = 'none';
    document.getElementById('album-content').style.display = 'none';
  }
}

function initListeners(session) {
  console.log('initListeners')
  document.getElementById('signup-form').addEventListener('submit', handleSignUp)
  document.getElementById('login-form').addEventListener('submit', handleLogin)
  
  var logoutLink = document.getElementById('LoggedInUser')
  if (logoutLink != null) {
    logoutLink.onclick = function() { 
      handleLogout()
      return false;
    }
  }
  
  var albumContent = document.getElementById('album-content')
  if (albumContent) {
    if (session) {
      if (session.user) {
        console.log ('initListeners showing album-content')
        albumContent.style.display = 'block'
      } 
    } else {
      console.log ('initListeners hiding album-content')
      albumContent.style.display = 'none'
    }
  } else {
    console.log('initListeners can not show/hide album-content, not defined')
  }
}