// See PRReviewState enum in PRReview.m
var ReviewState = {
  Pending: 0,
  Approve: 1,
  RequestChanges: 2,
  Comment: 3,
  Dismiss: 4
};

var ReviewStateColors = {
  Red: '#CB2431',
  Green: "#2CBE4E",
  Yellow: '#FFC500'
};

export default function reviewStateToUI(state) {
  var icon, action, bg = '#555';
  switch (state) {
    case ReviewState.Pending:
      icon = 'fa-commenting';
      action = 'started a review';
      break;
    case ReviewState.Approve:
      icon = 'fa-thumbs-up';
      action = 'approved these changes';
      bg = ReviewStateColors.Green;
      break;
    case ReviewState.RequestChanges:
      icon = 'fa-thumbs-down'
      action = 'requested changes';
      bg = ReviewStateColors.Red;
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

export { ReviewState, reviewStateToUI, ReviewStateColors };


