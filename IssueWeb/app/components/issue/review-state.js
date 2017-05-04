// See PRReviewState enum in PRReview.m
var ReviewState = {
  Pending: 0,
  Approve: 1,
  RequestChanges: 2,
  Comment: 3,
  Dismiss: 4
}

export default function reviewStateToUI(state) {
  var icon, action, bg = '#555';
  switch (state) {
    case ReviewState.Pending:
      icon = 'fa-commenting';
      action = 'saved a pending review';
      break;
    case ReviewState.Approve:
      icon = 'fa-thumbs-up';
      action = 'approved these changes';
      bg = 'green';
      break;
    case ReviewState.RequestChanges:
      icon = 'fa-thumbs-down'
      action = 'requested changes';
      bg = 'red';
      break;
    case ReviewState.Comment:
      icon = 'fa-comments';
      action = 'reviewed';
      break;
    case ReviewState.Dismissed:
      icon = 'fa-ban';
      action = 'added a review that was dismissed';
      break;
  }
  return { icon, action, bg };
}

export { ReviewState, reviewStateToUI };


