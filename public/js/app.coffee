_ = window._

RootCtrl = ($scope, $document) ->
  $scope.updateTitle = (title) ->
    $document[0].title = title

  $scope.places = [
    { name: 'Hacker News', path: '/' }
    { name: 'r/Commandline', path: '/r/commandline' }
    { name: 'r/Linux', path: '/r/linux' }
    { name: 'r/Programming', path: '/r/programming' }
  ]
  $scope.themes = ['Amelia', 'Cyborg', 'Default', 'Flatly', 'Slate', 'Yeti']

  $scope.setTheme = (index = 1) ->
    localStorage.theme = index
    $scope.themeName = $scope.themes[index]

  $scope.setTheme localStorage.theme

  #loading indicator
  $scope.loading = true
  $scope.$on '$stateChangeStart', ->
    $scope.loading = true
  $scope.$on '$stateChangeSuccess', ->
    $scope.loading = false


#HN Controllers:
Home = ($scope, stories) ->
  $scope.updateTitle 'Hacker News'
  @posts = stories
  @comments = []
  return

Home.resolve =
  stories: ($hn) ->
    $hn.getTopStories()

Story = ($scope, story) ->
  $scope.updateTitle story.title
  @posts = [story]
  @comments = story.kids
  return

Story.resolve =
  story: ($hn, $stateParams) ->
    $hn.getStory $stateParams.id


#Reddit Controllers:
Subreddit = ($scope, data) ->
  $scope.updateTitle data.posts[0].subreddit
  @posts = data.posts
  @comments = data.comments
  return

Subreddit.resolve =
  data: ($rdt, $stateParams) ->
    $rdt.getData $stateParams

Thread = ($scope, data) ->
  $scope.updateTitle data.posts[0].title
  @posts = data.posts
  @comments = data.comments
  return

Thread.resolve =
  data: ($rdt, $stateParams) ->
    $rdt.getData $stateParams


#Services
$hn = ($firebase, $q) ->
  baseUrl = 'https://hacker-news.firebaseio.com/v0'
  getFb = (url) -> $firebase new Firebase url

  getItem = (id) ->
    getFb(baseUrl + '/item/' + id).$asObject().$loaded()

  getItemRecursive = (id) ->
    getItem(id).then (item) ->
      if item.kids
        $q.all(_.map item.kids, getItemRecursive).then (kids) ->
          item.kids = kids
          item
      else
        item

  getStory: getItemRecursive
  getTopStories: ->
    getFb(baseUrl + '/topstories').$asArray().$loaded().then (data) =>
      data = data.slice 0, 100
      $q.all _.map _.pluck(data, '$value'), getItem

$rdt = ($http) ->
  parseComments = (data, level = 1) ->
    for c in data.data.children
      if c.kind is 'more'
        continue
      c = c.data
      c.score = c.ups - c.downs
      c.body_html = _.unescape c.body_html
      if c.replies
        if level is 8
          c.more = true
        else
          c.replies = parseComments c.replies, level + 1
      c

  parsePosts = (data) ->
    _.map _.pluck(data.data.children, 'data'), (post) ->
      post.title = _.unescape post.title
      post.selftext_html = _.unescape post.selftext_html
      post

  buildUrl = (params) ->
    params = _.extend limit: 500, params
    url = "http://www.reddit.com/r/#{params.subreddit}/"
    url += "comments/#{params.id}/" if params.id
    url += params.sort if params.sort
    "#{url}.json?#{$.param _.omit params, 'subreddit', 'id'}"

  getData: (params) ->
    $http.get(buildUrl(params)).then (res) ->
      if params.id
        posts: parsePosts res.data[0]
        comments: parseComments res.data[1]
      else
        posts: parsePosts res.data
        comments: []


#Filters
timeago =  -> (timestamp) ->
  moment(timestamp * 1000).fromNow()


#Config / States
config = ($stateProvider, $urlRouterProvider, $locationProvider) ->
  $urlRouterProvider.otherwise '/'
  $stateProvider
    .state 'Home',
      url: '/'
      templateUrl: '/static/hn-template.html'
      controller: 'Home'
      controllerAs: 'vm'
      resolve: Home.resolve
    .state 'Story',
      url: '/:id'
      templateUrl: '/static/hn-template.html'
      controller: 'Story'
      controllerAs: 'vm'
      resolve: Story.resolve
    .state 'Subreddit',
      url: '/r/:subreddit?sort&t'
      templateUrl: '/static/rdt-template.html'
      controller: 'Subreddit'
      controllerAs: 'vm'
      resolve: Subreddit.resolve
    .state 'Thread',
      url: '/r/:subreddit/:id?sort&t'
      templateUrl: '/static/rdt-template.html'
      controller: 'Thread'
      controllerAs: 'vm'
      resolve: Thread.resolve
  $locationProvider.html5Mode true


#Angular
angular
  .module 'app', ['ui.router', 'ngSanitize', 'firebase']
  .config config
  .controller 'Home', Home
  .controller 'Story', Story
  .controller 'Thread', Thread
  .controller 'Subreddit', Subreddit
  .controller 'RootCtrl', RootCtrl
  .factory '$hn', $hn
  .factory '$rdt', $rdt
  .filter 'timeago', timeago
