angular.module('beamng.apps')
    .directive('dragMPLeaderboard', ['bngApi', 'StreamsManager', '$state', function (bngApi, StreamsManager, $state) {
        return {
            templateUrl: '/ui/modules/apps/DragMPLeaderboard/template.html',
            replace: true,
            restrict: 'EA',
            link: function (scope, element, attrs) {
                scope.show = true
                scope.toggleShow = () => {
                    scope.show = !scope.show
                }
            }
        }
    }]);
