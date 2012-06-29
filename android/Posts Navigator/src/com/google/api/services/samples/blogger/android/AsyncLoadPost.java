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

    import android.app.ProgressDialog;
    import android.os.AsyncTask;
    import android.util.Log;

    import com.google.api.services.blogger.model.Post;

    /**
     * Asynchronously load a post with a progress dialog.
     * 
     * @author Yaniv Inbar
     * @author Brett Morgan
     */
    public class AsyncLoadPost extends AsyncTask<String, Void, Post> {

      /** TAG for logging. */
      private static final String TAG = "AsyncLoadPostList";

      private final PostDisplayActivity postDisplayActivity;
      private final ProgressDialog dialog;
      private com.google.api.services.blogger.Blogger service;

      AsyncLoadPost(PostDisplayActivity postDisplayActivity) {
        this.postDisplayActivity = postDisplayActivity;
        service = postDisplayActivity.service;
        dialog = new ProgressDialog(postDisplayActivity);
      }

      @Override
      protected void onPreExecute() {
        dialog.setMessage("Loading post list...");
        dialog.show();
      }

      @Override
      protected Post doInBackground(String... postIds) {
        try {
          String postId = postIds[0];
          return service.posts()
              .get(PostListActivity.BLOG_ID, postId)
              .setFields("title,content")
              .execute();
        } catch (IOException e) {
          Log.e(TAG, e.getMessage());
          return new Post().setTitle(e.getMessage());
        }
      }

      @Override
      protected void onPostExecute(Post result) {
        dialog.dismiss();
        postDisplayActivity.display(result);
      }
    }