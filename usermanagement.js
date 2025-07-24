<!-- code for handling login/logout/signup -->


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
  document.getElementById('auth-view').style.display = 'none'
  document.getElementById('LoggedInUser').style.display = 'block';
  document.getElementById('LoggedInUser').innerHTML = "logged in as <a href=\"#\" title=\"click to log out\">" + username + "</a>";
  var content = document.getElementById('album-content');
  content.style.display = 'block';
}

function handleLogout() {
  userbase.signOut()
    .then(() => resetAuthFields())
    .catch((e) => document.getElementById('logout-error').innerText = e)
}

function resetAuthFields() {
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

function initListeners() {
  console.log('entering initListeners');

  document.getElementById('signup-form').addEventListener('submit', handleSignUp)
  document.getElementById('login-form').addEventListener('submit', handleLogin)
  
  var logoutLink = document.getElementById('LoggedInUser')
  logoutLink.onclick = function() { 
    handleLogout()
    return false;
  }
  
  console.log('leaving initListeners');

}