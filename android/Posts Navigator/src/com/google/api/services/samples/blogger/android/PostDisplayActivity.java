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

import java.util.logging.Level;
import java.util.logging.Logger;

import android.app.Activity;
import android.os.Bundle;
import android.support.v4.app.NavUtils;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.webkit.WebView;
import android.widget.TextView;

import com.google.api.client.extensions.android2.AndroidHttp;
import com.google.api.client.extensions.android3.json.AndroidJsonFactory;
import com.google.api.client.googleapis.services.GoogleKeyInitializer;
import com.google.api.client.http.HttpTransport;
import com.google.api.client.json.JsonFactory;
import com.google.api.services.blogger.model.Post;

public class PostDisplayActivity extends Activity {

  private static String TAG = "PostDisplay";

  /** Logging level for HTTP requests/responses. */
  private static final Level LOGGING_LEVEL = Level.ALL;

  /** Choose the right HttpTransport depending on Android version. */
  final HttpTransport transport = AndroidHttp.newCompatibleTransport();

  /** The JSON factory to use to marshall data onto the wire. */
  final JsonFactory jsonFactory = new AndroidJsonFactory();

  /** The facade object for accessing Blogger API v3. */
  com.google.api.services.blogger.Blogger service;


  @Override
  public void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    setContentView(R.layout.activity_post_display);
    getActionBar().setDisplayHomeAsUpEnabled(true);

    Bundle extras = getIntent().getExtras();
    if (extras != null) {
      String postId = extras.getString(PostListActivity.POST_ID_KEY);
      Log.v(TAG, "postId: " + postId);

      // We shouldn't need ClientCredentials... but I can't figure out why it isn't binding.
      ClientCredentials.errorIfNotSpecified();

      service =
          new com.google.api.services.blogger.Blogger.Builder(transport, jsonFactory, null)
              .setApplicationName("Google-BloggerAndroidSample/1.0")
              .setJsonHttpRequestInitializer(new GoogleKeyInitializer(ClientCredentials.KEY))
              .build();
      Logger.getLogger("com.google.api.client").setLevel(LOGGING_LEVEL);
      new AsyncLoadPost(this).execute(postId);
    }
  }

  @Override
  public boolean onCreateOptionsMenu(Menu menu) {
    getMenuInflater().inflate(R.menu.activity_post_display, menu);
    return true;
  }


  @Override
  public boolean onOptionsItemSelected(MenuItem item) {
    switch (item.getItemId()) {
      case android.R.id.home:
        NavUtils.navigateUpFromSameTask(this);
        return true;
    }
    return super.onOptionsItemSelected(item);
  }

  public void display(Post result) {
    Log.v(TAG, "Title: " + result.getTitle());
    Log.v(TAG, "Content: " + result.getContent());
    ((TextView) findViewById(R.id.title)).setText(result.getTitle());
    ((WebView) findViewById(R.id.content)).loadDataWithBaseURL(null, result.getContent(),
        "text/html", "utf-8", null);

  }

}