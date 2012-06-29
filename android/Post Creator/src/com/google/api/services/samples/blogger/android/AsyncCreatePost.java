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

import android.app.AlertDialog;
import android.app.Dialog;
import android.app.ProgressDialog;
import android.content.DialogInterface;
import android.os.AsyncTask;
import android.util.Log;

import com.google.api.services.blogger.model.Post;

    /**
     * Asynchronously load a post with a progress dialog.
     * 
     * @author Yaniv Inbar
     * @author Brett Morgan
     */
    public class AsyncCreatePost extends AsyncTask<Post, Void, AsyncCreatePostResult> {

      /** TAG for logging. */
      private static final String TAG = "AsyncCreatePost";

      private final CreatePostActivity createPostActivity;
      private final ProgressDialog dialog;
      private com.google.api.services.blogger.Blogger service;

      AsyncCreatePost(CreatePostActivity createPostActivity) {
        Log.v(TAG, "start of CreatePost async task");
        this.createPostActivity = createPostActivity;
        service = createPostActivity.service;
        dialog = new ProgressDialog(createPostActivity);
      }

      @Override
      protected void onPreExecute() {
        Log.v(TAG, "Popping up waiting dialog");
        dialog.setMessage("Creating post...");
        dialog.show();
      }

      @Override
      protected AsyncCreatePostResult doInBackground(Post... args) {
        Post post = args[0];
        try {
          Log.v(TAG, "executing the posts.insert call on Blogger API v3");
          Post postResult = service.posts().insert(CreatePostActivity.BLOG_ID, post).execute();
          Log.v(TAG, "call succeeded");
          return new AsyncCreatePostResult(postResult, "Post Created", "postId: "+postResult.getId());
        } catch (IOException e) {
          Log.e(TAG, e.getMessage() == null ?"null" : e.getMessage());
          createPostActivity.handleGoogleException(e);

          // This is a less than optimal way of handling this situation.
          // A more elegant solution would involve using a SyncAdaptor...
          return new AsyncCreatePostResult(post, "Create Failed", "Please Retry");
        }
      }

      @Override
      protected void onPostExecute(AsyncCreatePostResult result) {
        Log.v(TAG, "Async complete, pulling down dialog");
        dialog.dismiss();
        createPostActivity.display(result.getPost());
        createAlertDialog(result.getResultDialogTitle(), result.getResultDialogTitle());
        createPostActivity.onRequestCompleted();
      }

      private void createAlertDialog(String title, String message) {
        final AlertDialog alertDialog = new AlertDialog.Builder(createPostActivity).create();
        alertDialog.setTitle(title);
        alertDialog.setMessage(message);
        alertDialog.setButton(Dialog.BUTTON_POSITIVE, "OK", new Dialog.OnClickListener() {

          @Override
          public void onClick(DialogInterface dialog, int which) {
            alertDialog.dismiss();
          }
        });
        alertDialog.show();

      }

    }