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

import java.util.ArrayList;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

import android.app.ListActivity;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.ArrayAdapter;
import android.widget.ListView;

import com.google.api.client.extensions.android2.AndroidHttp;
import com.google.api.client.extensions.android3.json.AndroidJsonFactory;
import com.google.api.client.googleapis.services.GoogleKeyInitializer;
import com.google.api.client.http.HttpTransport;
import com.google.api.client.json.JsonFactory;
import com.google.api.services.blogger.model.Post;

/**
 * Sample for Blogger API on Android. It shows how to get a list of posts.
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

public class PostListActivity extends ListActivity {

  /** Intent key for passing over postId to drill down activity. */
  public static final String POST_ID_KEY = "POST_ID";

  /** The blogId for <code>http://code.blogger.com/</code>. */
  public static String BLOG_ID = "4807746521902285462";

  /** Logging level for HTTP requests/responses. */
  private static final Level LOGGING_LEVEL = Level.ALL;

  /** TAG for logging. */
  @SuppressWarnings("unused")
  private static final String TAG = "PostList";

  /** Choose the right HttpTransport depending on Android version. */
  final HttpTransport transport = AndroidHttp.newCompatibleTransport();

  /** The JSON factory to use to marshall data onto the wire. */
  final JsonFactory jsonFactory = new AndroidJsonFactory();

  /** The facade object for accessing Blogger API v3. */
  com.google.api.services.blogger.Blogger service;

  private List<Post> posts;

  @Override
  public void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);

    ClientCredentials.errorIfNotSpecified();

    service =
        new com.google.api.services.blogger.Blogger.Builder(transport, jsonFactory, null)
            .setApplicationName("Google-BloggerAndroidSample/1.0")
            .setJsonHttpRequestInitializer(new GoogleKeyInitializer(ClientCredentials.KEY))
            .build();
    Logger.getLogger("com.google.api.client").setLevel(LOGGING_LEVEL);
    new AsyncLoadPostList(this).execute();

  }

  public void setModel(List<Post> result) {
    this.posts = result;
    List<String> titles = new ArrayList<String>(result.size());
    for (Post post : posts) {
      titles.add(post.getTitle());
    }
    this.setListAdapter(new ArrayAdapter<String>(this, android.R.layout.simple_list_item_1, titles));
  }

  @Override
  protected void onListItemClick(ListView l, View v, int position, long id) {
    String postId = this.posts.get(position).getId().toString();
    String title = this.posts.get(position).getTitle();
    Log.v(TAG, "postId: " + postId + " selected '" + title + "'");

    Intent i = new Intent(getApplicationContext(), PostDisplayActivity.class);
    i.putExtra(POST_ID_KEY, postId);
    startActivity(i);

    super.onListItemClick(l, v, position, id);
  }
  
}