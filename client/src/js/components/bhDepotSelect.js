angular.module('bhima.components')
  .component('bhDepotSelect', {
    templateUrl : 'modules/templates/bhDepotSelect.tmpl.html',
    controller  : DepotSelectController,
    transclude  : true,
    bindings    : {
      depotUuid        : '<',
      onSelectCallback : '&',
      required         : '<?',
    },
  });

DepotSelectController.$inject = ['DepotService', 'NotifyService'];

/**
 * Depot selection component
 */
function DepotSelectController(Depots, Notify) {
  const $ctrl = this;

  $ctrl.$onInit = () => {
    // load all depots
    Depots.read()
      .then(depots => {
        $ctrl.depots = depots;
      })
      .catch(Notify.handleError);
  };

  // fires the onSelectCallback bound to the component boundary
  $ctrl.onSelect = depot => {
    $ctrl.onSelectCallback({ depot });
  };
}
