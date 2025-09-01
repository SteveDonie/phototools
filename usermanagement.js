/*
 * code for handling login/logout/signup.
 * 
 * See also userAdmin.html - it has a lot of similar code for dealing with
 * userbase, etc.
 *
 * 
*/

function handleSignUp(e) {
  e.preventDefault()

  const username = document.getElementById('signup-username').value
  const password = document.getElementById('signup-password').value
  const email = document.getElementById('signup-email').value

  userbase.signUp({username, password, email})
    .then((user, email) => 
      createUserProfile(user, email));
}

function createUserProfile(user, email) {
  console.log(`User registered: ${user.username}`);

  // Create their profile in the admin database
  const profileResult = updateUserProfile(user, {
      email: email,
  });

  if (!profileResult.success) {
      console.warn('Profile creation failed:', profileResult.error);
      // You might want to delete the user account if profile creation fails
      // This depends on your requirements
  }

  return {
      user: user,
      isAuthorized: false, // New users start unauthorized
      profileResult: profileResult
  };

}

function handleLogin(e) {
  e.preventDefault()

  const username = document.getElementById('login-username').value
  const password = document.getElementById('login-password').value

/*
  userbase.signIn({ username, password, rememberMe: 'local' })
    .then((user) => showUserLoggedIn(user))
    .catch((e) => document.getElementById('login-error').innerHTML = e)
*/
  try {
    const result = signInUserWithProfile(username, password);
    
    if (result.isAuthorized) {
        showUserLoggedIn(result.user);
    } else {
        showUnauthorizedMessage();
    }
  } catch (error) {
      showErrorMessage('Login failed: ' + error.message);
  }
}

function showUserLoggedIn(user) {
  var msg = 'showUserLoggedIn(' + JSON.stringify(user, null, 2) + ')'
  console.log(msg)
  document.getElementById('auth-view').style.display = 'none'
  document.getElementById('album-content').style.display = 'block';
  document.getElementById('LoggedInUser').style.display = 'block';
  var userLoginInfo = "logged in as <a href=\"#\" title=\"click to log out\">" + user.username + "</a>";
  document.getElementById('LoggedInUser').innerHTML = userLoginInfo;
  if (user.username == 'stevedonie') {
    var userAdminInfo = `&nbsp;&nbsp;<a href=\"https://album.donie.us/personal/userAdmin.html\">User Admin</a>`;
    document.getElementById('UserAdmin').innerHTML = userAdminInfo;
    document.getElementById('UserAdmin').style.display = 'block';
  }
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
    document.getElementById('UserAdmin').innerText = '';
    document.getElementById('LoggedInUser').style.display = 'none';
    document.getElementById('UserAdmin').style.display = 'none';
    document.getElementById('album-content').style.display = 'none';
  }
}

function initListeners(session) {
  console.log('initListeners called, session is (' + JSON.stringify(session, null, 2) + ')')
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
        console.log ('session AND session.user are truthy - (' + JSON.stringify(session, null, 2) + ') initListeners showing album-content')
        albumContent.style.display = 'block'
      } else {
        console.log ('session is truthy but session.user is falsy - (' + JSON.stringify(session, null, 2) + '), initListeners hiding album-content')
        handleLogout()
        albumContent.style.display = 'none'
      }        
    } else {
      console.log ('session is falsy - (' + JSON.stringify(session, null, 2) + '), initListeners hiding album-content')
      albumContent.style.display = 'none'
    }
  } else {
    console.log('initListeners can not show/hide album-content, script not able to find element with id album-content')
  }
}


function showUnauthorizedMessage() {
    document.body.innerHTML = `
        <div style="text-align: center; padding: 50px;">
            <h2>Access Pending</h2>
            <p>Your account is pending approval. Please contact the administrator.</p>
            <p>If you don't know who the administrator is or how to contact them,
            there's no way you're going to get approved, so just move on.</p>
            <button onclick="userbase.signOut().then(() => location.reload())">
                Sign Out
            </button>
        </div>
    `;
}

/**
 * Updates or creates user profile in the admin-accessible database
 * This function should be called whenever a user logs in to your main photo album app
 * 
 * @param {Object} user - The Userbase user object from sign-in/sign-up
 * @param {Object} additionalData - Optional additional data to store (email, name, etc.)
 * @returns {Promise<Object>} The created or updated profile data
 */
async function updateUserProfile(user, additionalData = {}) {
    if (!user || !user.userId) {
        throw new Error('Invalid user object provided');
    }

    const DATABASE_NAME = 'user-profiles';
    let database = null;
    
    try {
        // Open the user profiles database (create if doesn't exist)
        database = await userbase.openDatabase({ 
            databaseName: DATABASE_NAME,
            changeHandler: (profiles) => {
                // Optional: Handle real-time updates to user profiles
                console.log('User profiles opened:', profiles);
            }
        });

        console.log(`Database "${DATABASE_NAME}" opened successfully`);

    } catch (error) {
        // If database doesn't exist, it will be created on first insert
        console.log(`Database "${DATABASE_NAME}" will be created on first use`);
    }

    try {
        // Get current database contents to find existing profile
        let existingProfile = null;
        let allProfiles = [];

        // We need to track profiles through the changeHandler
        // First, let's try to open the database to get existing data
        let databaseOpened = false;
        
        try {
            await userbase.openDatabase({ 
                databaseName: DATABASE_NAME,
                changeHandler: (profiles) => {
                    allProfiles = profiles || [];
                    
                    // Find existing profile for this user
                    existingProfile = allProfiles.find(item => 
                        item.userId === user.userId
                    );
                }
            });
            databaseOpened = true;
            
        } catch (openError) {
            console.log('Database doesn\'t exist yet, will create on first insert');
        }

        // Prepare profile data
        const currentTime = new Date().toISOString();
        
        const profileData = {
            userId: user.userId,
            username: user.username,
            email: user.email || additionalData.email || '',
            
            // Preserve existing authorization status or default to false
            isAuthorized: existingProfile?.isAuthorized || false,
            
            // Timestamps
            lastActive: currentTime,
            updatedAt: currentTime,
            
            // Preserve first seen date or set it now
            firstSeen: existingProfile?.firstSeen || 
                      existingProfile?.registeredAt || 
                      currentTime,
            
            // Login tracking
            loginCount: (existingProfile?.loginCount || 0) + 1,
            
            // Additional data from parameters
            deviceType: additionalData.deviceType || existingProfile?.deviceType || '',
            location: additionalData.location || existingProfile?.location || '',
            displayName: additionalData.displayName || existingProfile?.displayName || '',
            
            // Preserve admin-set fields
            adminNotes: existingProfile?.adminNotes || '',
            lastAuthorizedBy: existingProfile?.lastAuthorizedBy || '',
            authorizedAt: existingProfile?.authorizedAt || ''
        };

        let result;

        if (existingProfile) {
            // Update existing profile
            console.log(`Updating existing profile for user: ${user.username}`);
            
            result = await userbase.updateItem({
                databaseName: DATABASE_NAME,
                itemId: existingProfile.itemId,
                profile: profileData
            });

            console.log('Profile updated successfully');

        } else {
            // Create new profile
            console.log(`Creating new profile for user: ${user.username}`);
            
            // Add creation timestamp for new profiles
            profileData.createdAt = currentTime;
            
            result = await userbase.insertItem({
                databaseName: DATABASE_NAME,
                item: profileData
            });

            console.log('New profile created successfully');
        }

        // Return the profile data for use in your app
        return {
            success: true,
            profileData: profileData,
            isNewProfile: !existingProfile,
            itemId: result?.itemId || existingProfile?.itemId
        };

    } catch (error) {
        console.error('Error updating user profile:', error);
        
        // Log more specific error information
        if (error.name === 'DatabaseNotOpen') {
            console.error('Database connection issue. Retrying...');
            // Could implement retry logic here
        } else if (error.name === 'ItemNotFound') {
            console.error('Attempted to update non-existent profile');
        } else if (error.name === 'ItemAlreadyExists') {
            console.error('Profile creation conflict');
        }
        
        // Return error information instead of throwing
        // This prevents login failures due to profile update issues
        return {
            success: false,
            error: error.message,
            profileData: null
        };
    }
}

/**
 * Helper function to safely get user's current authorization status
 * Use this before loading the photo album
 * 
 * @param {Object} user - The Userbase user object
 * @returns {Promise<boolean>} Whether the user is authorized
 */
async function checkUserAuthorization(user) {
    if (!user || !user.userId) {
        return false;
    }

    return new Promise((resolve) => {
        let resolved = false;
        
        userbase.openDatabase({
            databaseName: 'user-profiles',
            changeHandler: (profiles) => {
                if (resolved) return; // Prevent multiple resolutions
                
                const userProfile = profiles.find(item => 
                    item.userId === user.userId
                );
                
                const isAuthorized = userProfile?.isAuthorized || false;
                
                console.log(`User ${user.username} authorization status: ${isAuthorized}`);
                resolved = true;
                resolve(isAuthorized);
            }
        }).catch(error => {
            console.error('Error checking authorization:', error);
            if (!resolved) {
                resolved = true;
                resolve(false); // Default to unauthorized on error for security
            }
        });
    });
}

/**
 * Enhanced login function that includes profile updating
 * Replace your existing login function with this
 */
async function signInUserWithProfile(username, password, additionalData = {}) {
    try {
        // Sign in to Userbase
        const user = await userbase.signIn({ username, password });
        console.log(`User signed in: ${user.username}`);
        
        // Update their profile in the admin database
        const profileResult = await updateUserProfile(user, additionalData);
        
        if (!profileResult.success) {
            console.warn('Profile update failed, but login succeeded:', profileResult.error);
            // Continue with login even if profile update fails
        }
        
        // Check if user is authorized to access the photo album
        const isAuthorized = await checkUserAuthorization(user);
        
        return {
            user: user,
            isAuthorized: isAuthorized,
            profileResult: profileResult
        };
        
    } catch (error) {
        console.error('Sign in failed:', error);
        throw error;
    }
}

/**
 * Enhanced registration function that creates profile immediately
 * Replace your existing registration function with this
 */
async function signUpUserWithProfile(username, password, email = '', additionalData = {}) {
    try {
        // Sign up to Userbase
        const user = await userbase.signUp({ 
            username, 
            password,
            email: email
        });
        
        console.log(`User registered: ${user.username}`);
        
        // Create their profile in the admin database
        const profileResult = await updateUserProfile(user, {
            email: email,
            deviceType: additionalData.deviceType || '',
            location: additionalData.location || '',
            displayName: additionalData.displayName || ''
        });
        
        if (!profileResult.success) {
            console.warn('Profile creation failed:', profileResult.error);
            // You might want to delete the user account if profile creation fails
            // This depends on your requirements
        }
        
        return {
            user: user,
            isAuthorized: false, // New users start unauthorized
            profileResult: profileResult
        };
        
    } catch (error) {
        console.error('Sign up failed:', error);
        throw error;
    }
}
