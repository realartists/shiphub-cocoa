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
      action = 'has a pending review';
      break;
    case ReviewState.Approve:
      icon = 'fa-thumbs-up';
      action = 'approved these changes';
      bg = 'green';
      break;
    case ReviewState.RequestChanges:
      icon = 'fa-thumbs-down'
      action = 'requested changes';
      bg = '#CB2431';
      break;
    case ReviewState.Comment:
      icon = 'fa-comments';
      action = 'reviewed';
      break;
    case ReviewState.Dismiss:
      icon = 'fa-ban';
      action = 'added a review that was dismissed';
      break;
    default:
      icon = 'fa-clock-o';
      action = 'was requested for review';
      break;
  }
  return { icon, action, bg };
}

export { ReviewState, reviewStateToUI };


