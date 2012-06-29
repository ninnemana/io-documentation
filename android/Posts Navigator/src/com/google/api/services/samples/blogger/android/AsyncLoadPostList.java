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
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import android.app.ProgressDialog;
import android.os.AsyncTask;
import android.util.Log;

import com.google.api.services.blogger.model.Post;
import com.google.api.services.blogger.model.PostList;

/**
 * Asynchronously load the post list with a progress dialog.
 * 
 * @author Yaniv Inbar
 * @author Brett Morgan
 */
public class AsyncLoadPostList extends AsyncTask<Void, Void, List<Post>> {

  /** TAG for logging. */
  private static final String TAG = "AsyncLoadPostList";

  private final PostListActivity postListActivity;
  private final ProgressDialog dialog;
  private com.google.api.services.blogger.Blogger service;

  AsyncLoadPostList(PostListActivity postListActivity) {
    this.postListActivity = postListActivity;
    service = postListActivity.service;
    dialog = new ProgressDialog(postListActivity);
  }

  @Override
  protected void onPreExecute() {
    dialog.setMessage("Loading post list...");
    dialog.show();
  }

  @Override
  protected List<Post> doInBackground(Void... arg0) {
    try {
      List<Post> result = new ArrayList<Post>();
      com.google.api.services.blogger.Blogger.Posts.List postsListAction = service.posts()
          .list(PostListActivity.BLOG_ID)
          .setFields("items(id,title),nextPageToken");
      PostList posts = postsListAction.execute();

      // Retrieve up to five pages of results.
      int page = 1;

      while (posts.getItems() != null && page < 5) {
        page++;
        result.addAll(posts.getItems());
        String pageToken = posts.getNextPageToken();
        if(pageToken == null) {
          break;
        }
        postsListAction.setPageToken(pageToken);
        posts = postsListAction.execute();
      }
      return result;
    } catch (IOException e) {
      Log.e(TAG, e.getMessage());
      return Collections.emptyList();
    }
  }

  @Override
  protected void onPostExecute(List<Post> result) {
    dialog.dismiss();
    postListActivity.setModel(result);
  }
}