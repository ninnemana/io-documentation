/*
     * Copyright (c) 2012 Google Inc.
     * 
     * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
     * in compliance with the License. You may obtain a copy of the License at
     * 
     * http://www.apache.org/licenses/LICENSE-2.0
     * 
     * Unless required by applicable law or agreed to in writing, software distributed under the License
     * is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
     * or implied. See the License for the specific language governing permissions and limitations under
     * the License.
     */
    package com.google.api.services.samples.blogger.android;

    import java.io.IOException;
    import java.util.logging.Level;
    import java.util.logging.Logger;

    import android.accounts.Account;
    import android.accounts.AccountManager;
    import android.accounts.AccountManagerCallback;
    import android.accounts.AccountManagerFuture;
    import android.accounts.AuthenticatorException;
    import android.accounts.OperationCanceledException;
    import android.app.Activity;
    import android.content.Intent;
    import android.content.SharedPreferences;
    import android.os.Bundle;
    import android.util.Log;
    import android.view.Menu;
    import android.view.MenuItem;
    import android.view.View;
    import android.widget.Button;
    import android.widget.EditText;

    import com.google.api.client.extensions.android2.AndroidHttp;
    import com.google.api.client.extensions.android3.json.AndroidJsonFactory;
    import com.google.api.client.googleapis.auth.oauth2.GoogleCredential;
    import com.google.api.client.googleapis.extensions.android2.auth.GoogleAccountManager;
    import com.google.api.client.googleapis.json.GoogleJsonResponseException;
    import com.google.api.client.http.HttpTransport;
    import com.google.api.client.json.JsonFactory;
    import com.google.api.services.blogger.Blogger;
    import com.google.api.services.blogger.BloggerScopes;
    import com.google.api.services.blogger.model.Post;

    /**
     * Sample for Blogger API on Android. It shows how to create a post.
     * <p>
     * To enable logging of HTTP requests/responses, change {@link #LOGGING_LEVEL} to
     * {@link Level#CONFIG} or {@link Level#ALL} and run this command:
     * </p>
     * 
     * <pre>
    adb shell setprop log.tag.HttpTransport DEBUG
     * </pre>
     * 
     * @author Brett Morgan
     */
    public class CreatePostActivity extends Activity {


      /** REPLACE ME WITH A BLOG ID OF SOMETHING YOU HAVE WRITE PRIVS ON. */
      public static final String BLOG_ID = "4807746521902285462";

      /** Logging level for HTTP requests/responses. */
      private static final Level LOGGING_LEVEL = Level.ALL;

      /** Logging tag. */
      private final String TAG = "CreatePost";

      /** Choose the right HttpTransport depending on Android version. */
      final HttpTransport transport = AndroidHttp.newCompatibleTransport();

      /** The JSON factory to use to marshall data onto the wire. */
      final JsonFactory jsonFactory = new AndroidJsonFactory();

      /** Facade object for Blogger API v3. */
      public Blogger service;

      /** OAuth2.0 scope for Read/Write access to Blogger. */
      private static final String AUTH_TOKEN_TYPE = "oauth2:" + BloggerScopes.BLOGGER;

      /** Intent Key for round tripping login. */
      private static final int REQUEST_AUTHENTICATE = 0;

      /** Shared Preferences key for the selected user's account name. */
      static final String PREF_ACCOUNT_NAME = "accountName";

      /** Shared Preferences key for storing the user's OAuth token. */
      static final String PREF_AUTH_TOKEN = "authToken";

      /** Account Manager to request auth from for Google Accounts. */
      GoogleAccountManager accountManager;

      /** Shared Preferences for storing auth credentials. */
      SharedPreferences settings;

      /** Selected account name we are authorizing as. */
      String accountName;

      /** HTTP rewriter responsible for managing lifetime of oauth2 credentials. */
      GoogleCredential credential = new GoogleCredential();


      /**
       * Create Post button. Used to prevent user from attempting to create posts until after they are
       * auth'd.
       */
      Button createPostButton;

      /** Whether we have received a 401. Used to initiate re-authorising the authToken. */
      private boolean received401;

      @Override
      public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_create_post);

        Log.v(TAG, "Capturing create_post");
        createPostButton = (Button) findViewById(R.id.create_post);
        Log.v(TAG, "Setting create_post's OnClickListener");
        createPostButton.setOnClickListener(new View.OnClickListener() {

          @Override
          public void onClick(View v) {
            String title = ((EditText) findViewById(R.id.title)).getText().toString();
            String content = ((EditText) findViewById(R.id.content)).getText().toString();
            Post createPost = new Post().setTitle(title).setContent(content);
            (new AsyncCreatePost(CreatePostActivity.this)).execute(createPost);
          }
        });

        Log.v(TAG, "Disabling create_post button");
        createPostButton.setEnabled(false);


        Log.v(TAG, "Building the Blogger API v3 service facade");
        service =
            new com.google.api.services.blogger.Blogger.Builder(transport, jsonFactory, credential)
                .setApplicationName("Google-BloggerAndroidSample/1.0")
                .build();
        Log.v(TAG, "Getting the private SharedPreferences instance");
        settings = getPreferences(MODE_PRIVATE);
        Log.v(TAG, "Retrieving the account name from settings");
        accountName = settings.getString(PREF_ACCOUNT_NAME, null);
        Log.v(TAG, "accountName: " + accountName);
        credential.setAccessToken(settings.getString(PREF_AUTH_TOKEN, null));
        Logger.getLogger("com.google.api.client").setLevel(LOGGING_LEVEL);
        accountManager = new GoogleAccountManager(this);
        gotAccount();

      }

      void gotAccount() {
        Log.v(TAG, "Retreving the account for " + accountName);
        Account account = accountManager.getAccountByName(accountName);
        if (account == null) {
          Log.v(TAG, "account was null, forcing user to choose account");
          chooseAccount();
          return;
        }
        if (credential.getAccessToken() != null) {
          Log.v(TAG, "We have an AccessToken");
          onAuthToken();
          return;
        }
        Log.v(TAG, "We have an account, but no stored Access Token. Requesting from the AccountManager");
        accountManager.getAccountManager().getAuthToken(account, AUTH_TOKEN_TYPE, null, true,
            new AccountManagerCallback<Bundle>() {

              public void run(AccountManagerFuture<Bundle> future) {
                try {
                  Bundle bundle = future.getResult();
                  if (bundle.containsKey(AccountManager.KEY_INTENT)) {
                    Intent intent = bundle.getParcelable(AccountManager.KEY_INTENT);
                    intent.setFlags(intent.getFlags() & ~Intent.FLAG_ACTIVITY_NEW_TASK);
                    Log.v(TAG, "We need AccountManager to talk to the user. Starting Activity.");
                    startActivityForResult(intent, REQUEST_AUTHENTICATE);
                  } else if (bundle.containsKey(AccountManager.KEY_AUTHTOKEN)) {
                    Log.v(TAG, "AccountManager handed us a AuthToken, storing for future reference");
                    setAuthToken(bundle.getString(AccountManager.KEY_AUTHTOKEN));
                    onAuthToken();
                  }
                } catch (Exception e) {
                  Log.e(TAG, e.getMessage(), e);
                }
              }
            }, null);
      }

      private void chooseAccount() {
        Log.v(TAG, "Asking the AccountManager to find us an account to auth as");
        accountManager.getAccountManager().getAuthTokenByFeatures(GoogleAccountManager.ACCOUNT_TYPE,
            AUTH_TOKEN_TYPE, null, CreatePostActivity.this, null, null,
            new AccountManagerCallback<Bundle>() {

              public void run(AccountManagerFuture<Bundle> future) {
                Bundle bundle;
                try {
                  Log.v(TAG, "Requesting result");
                  bundle = future.getResult();
                  Log.v(TAG, "Retreiving Account Name");
                  setAccountName(bundle.getString(AccountManager.KEY_ACCOUNT_NAME));
                  Log.v(TAG, "Retreiving Auth Token");
                  setAuthToken(bundle.getString(AccountManager.KEY_AUTHTOKEN));
                  Log.v(TAG, "Stored for future reference");
                  onAuthToken();
                } catch (OperationCanceledException e) {
                  // user canceled
                } catch (AuthenticatorException e) {
                  Log.e(TAG, e.getMessage(), e);
                } catch (IOException e) {
                  Log.e(TAG, e.getMessage(), e);
                }
              }
            }, null);
      }

      void setAccountName(String accountName) {
        SharedPreferences.Editor editor = settings.edit();
        editor.putString(PREF_ACCOUNT_NAME, accountName);
        editor.commit();
        this.accountName = accountName;
        Log.v(TAG, "Stored accountName: " + accountName);
      }

      void setAuthToken(String authToken) {
        SharedPreferences.Editor editor = settings.edit();
        editor.putString(PREF_AUTH_TOKEN, authToken);
        editor.commit();
        credential.setAccessToken(authToken);
        Log.v(TAG, "Stored authToken");
      }

      @Override
      protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        Log.v(TAG, "Returning from another Activity");
        super.onActivityResult(requestCode, resultCode, data);
        switch (requestCode) {
          case REQUEST_AUTHENTICATE:
            Log.v(TAG, "request code is REQUEST_AUTHENTICATE");
            if (resultCode == RESULT_OK) {
              Log.v(TAG, "Result was RESULT_OK");
              gotAccount();
            } else {
              Log.v(TAG, "Result was NOT RESULT_OK");
              chooseAccount();
            }
            break;
        }
      }

      void onAuthToken() {
        Log.v(TAG, "Enabling create_post button");
        createPostButton.setEnabled(true);
      }


      @Override
      public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.activity_create_post, menu);
        return true;
      }



      @Override
      public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
          case R.id.menu_accounts:
            chooseAccount();
            return true;
        }
        return super.onOptionsItemSelected(item);
      }

      public void display(Post result) {
        Log.v(TAG, "Displaying " + result.getTitle());
        ((EditText) findViewById(R.id.title)).setText(result.getTitle());
        ((EditText) findViewById(R.id.content)).setText(result.getContent());
      }

      void onRequestCompleted() {
        Log.v(TAG, "Request completed, throwing away 401 state");
        received401 = false;
      }

      /**
       * Handle an IO exception encountered by the background AsyncTask. It may be because the stored
       * AuthToken is stale.
       * 
       * @param e The exception caught in the AsyncTask.
       * @return Returns if we believe we have a valid AuthToken (for re-try purposes).
       */
      void handleGoogleException(IOException e) {
        if (e instanceof GoogleJsonResponseException) {
          GoogleJsonResponseException exception = (GoogleJsonResponseException) e;
          if (exception.getStatusCode() == 401 && !received401) {
            Log.v(TAG, "Invalidating stored AuthToken due to received 401.");
            Log.v(TAG, "Remembering seen 401, to prevent re-auth loop");
            received401 = true;
            Log.v(TAG, "Invalidating AuthToken in AccountManager");
            accountManager.invalidateAuthToken(credential.getAccessToken());
            Log.v(TAG, "Deleting AccessToken from Credential");
            credential.setAccessToken(null);
            Log.v(TAG, "Removing AuthToken from private SharedPreferences");
            SharedPreferences.Editor editor2 = settings.edit();
            editor2.remove(PREF_AUTH_TOKEN);
            editor2.commit();
            Log.v(TAG, "Initiating authToken request from AccountManager");
            gotAccount();
            return;
          }
        }
        Log.e(TAG, e.getMessage(), e);
      }

    }