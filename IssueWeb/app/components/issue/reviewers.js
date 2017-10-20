import React, { createElement as h } from 'react'
import BBPromise from 'util/bbpromise.js'

import IssueState from '../../issue-state.js'
import { HeaderLabel, HeaderSeparator } from './issue-header.js'
import Completer from './completer.js'
import AssigneesPicker from './assignees-picker.js'
import { ReviewState, reviewStateToUI } from './review-state.js'
import ghost from 'util/ghost.js'
import { keypath, setKeypath } from 'util/keypath.js'

import './reviewers.css'

class AddReviewer extends React.Component {
  focus() {
    if (this.refs.picker) {
      this.refs.picker.focus();
    }
  }
  
  hasFocus() {
    if (this.refs.picker) {
      return this.refs.picker.hasFocus();
    } else {
      return false;
    }
  }
  
  needsSave() {
    if (this.refs.add) {
      return this.refs.add.needsSave();
    } else {
      return false;
    }
  }
  
  save() {
    if (this.refs.add && this.refs.add.needsSave()) {
      return this.refs.add.save();
    } else {
      return BBPromise.resolve();
    }
  }
  
  render() {
    var possibleReviewers = IssueState.current.assignees;
    var chosenReviewers = this.props.existingReviewers;
    
    var chosenReviewersLookup = chosenReviewers.reduce((o, l) => { o[l.login] = l; return o; }, {});
    var availableReviewers  = possibleReviewers.filter((l) => !(l.login in chosenReviewersLookup));

    return h(AssigneesPicker, {
      ref: "add",
      placeholder: 'Add Reviewer',
      availableAssigneeLogins: availableReviewers.map((l) => (l.login)),
      onAdd: this.props.addReviewer
    });
  }
}

class ReviewAtom extends React.Component {
  onDeleteClick() {
    if (this.props.onDelete) {
      this.props.onDelete(this.props.item.user.login);
    }
  }
  
  jump() {
    var id = `review.${this.props.item.review.id}`;
    var el = document.getElementById(id);
    console.log("jump", id, el);
    
    if (el) {
      el.scrollIntoView();
    }
  }
  
  render() {
    var icon, bg, del, click, title;
    var style = { color: 'white' };
    if (this.props.item.review) {
      var reviewUI = reviewStateToUI(this.props.item.review.state);
      icon = reviewUI.icon;
      bg = reviewUI.bg;
      title = reviewUI.action;
      Object.assign(style, {cursor:"pointer"});
      click = this.jump.bind(this);
    } else {
      click = null;
      icon = 'fa-question-circle';
      bg = '#999';
      title = "review requested";
      if (this.props.canDelete) {
        del = h('span', {className:'ReviewerDelete Clickable', onClick:this.onDeleteClick.bind(this)}, 
          h('i', {className:'fa fa-times'})
        );
      }
      Object.assign(style, {cursor:"default"});
    }
    style.backgroundColor = bg;
    
    return h("span", {className:"ReviewersAtomContainer"},
      h("span", {className:"ReviewsAtom", style:style, onClick:click, title},
        h('i', {className:`fa ${icon}`, style:{marginRight: '4px'}}),
        this.props.item.user.login,
        del
      )
    );
  }
}

class Reviewers extends React.Component {
  canEdit() {
    return IssueState.current.repoCanPush;
  }

  addReviewer(login) {
    var user = null;
    var matches = IssueState.current.assignees.filter((u) => u.login == login);
    if (matches.length > 0) {
      user = matches[0];
      return IssueState.current.addReviewer(user);
    } else {
      return BBPromise.resolve();
    }
  }
  
  deleteReviewer(login) {
    var user = null;
    var matches = IssueState.current.assignees.filter((u) => u.login == login);
    if (matches.length > 0) {
      user = matches[0];
      return IssueState.current.deleteReviewer(user);
    } else {
      return BBPromise.resolve();
    }
  }

  focus() {
    if (this.refs.addReviewer) {
      this.refs.addReviewer.focus();
    }
  }
  
  hasFocus() {
    if (this.refs.addReviewer) {
      return this.refs.addReviewer.hasFocus();
    } else {
      return false;
    }
  }
  
  needsSave() {
    return false;
  }
  
  save() {
    return BBPromise.resolve();
  }
  
  // return { user, review? } for all users who have submitted reviews or had them requested
  static latestReviews(issue, allReviews) {
    var items = [];
    
    var reviews = allReviews.filter(r => !!r.id);
    
    // find the most recent reviews for each user
    reviews.sort((a, b) => {
      var da, db;
      if (a.user.id < b.user.id) return -1;
      else if (a.user.id > b.user.id) return 1;
      else if ((da = new Date(a.submitted_at||a.created_at)) < (db = new Date(b.submitted_at||b.created_at))) return 1;
      else if (da > db) return -1;
      else return 0;
    });
    
    // reduce reviews such that we only have the latest review for each user
    reviews = reviews.reduce((accum, review) => {
      if (accum.length == 0) return [review];
      var prev = accum[accum.length-1];
      if (prev.user.id != review.user.id) {
        return accum.concat([review]);
      } else {
        return accum;
      }
    }, []);
    
    var reviewed = new Set();
    reviews.forEach(r => {
      reviewed.add(r.user.id);
      items.push({user:r.user, review:r});
    });
    
    // add in any requested reviewers who haven't reviewed
    issue.requested_reviewers.forEach(u => {
      if (!reviewed.has(u.id)) {
        items.push({user:u});
      }
    });
    
    items.sort((a, b) => {
      var al = a.user.login.toLowerCase();
      var bl = b.user.login.toLowerCase();
      if (al < bl) return -1;
      else if (al > bl) return 1;
      else return 0;
    });
        
    return items;
  }
  
  render() {
    var canEdit = this.canEdit();
    var items = Reviewers.latestReviews(this.props.issue, this.props.allReviews);
  
    var existingReviewers = items.map(i => i.user);
    existingReviewers.push(this.props.issue.user); // github doesn't allow the originator of a PR to be a reviewer
  
    return h('div', {className:'IssueReviewers'},
      h(HeaderLabel, {title:"Reviewers"}),
      canEdit?h(AddReviewer, {ref:"add", existingReviewers, addReviewer:this.addReviewer.bind(this)}):null,
      items.map((i, j) => h(ReviewAtom, { 
        item: i, 
        key:`atom.${i.user.id}`, 
        canDelete: canEdit,
        onDelete: this.deleteReviewer.bind(this)
      }))
    );
  }
}

export default Reviewers;