$(document).ready(function() {
  aggregate();
  checkAll();
  checkBoxToggleFields();
  colspans();
  collapseIconChange();
  colspans();
  fakeDateField();
  popover();
  initilizeUppy();
  selectpicker();
  spinner();
  toggleFields();
  toggles();
  tooltip();
  popup();
  inlineUpdate();
});

$(document).ajaxComplete(function() {
  initilizeUppy();
  selectpicker();
  toggleFields();
});

window.aggregate = function() {
  $("#aggregate").click(function(){
    var url = "/aggregated_jobs/aggregate";
    var line_item_ids = $('.check_line_item:checkbox:checked').map(function() {
      return this.value;
    }).get();
    $.ajax({
      type: 'GET',
      url: url,
      data: { line_item_ids: line_item_ids },
      dataType: 'script'
    });
    return false;
  });
}

window.checkBoxToggleFields = function() {
  $("[data-behaviour='check_box_toggle_fields']").each(function(i, el) {
    $(el).change(function() {
      var target = $('#' + $(el).data("target") + ' option');
      if($(el).is(":checked")) {
        target.prop('selected', true);
      } else {
        target.prop('selected', false);
      }
    });
  });
}

window.colspans = function() {
  $('td.colspan').each(function(i, el) {
    var count = 0
    $(el).closest('table').find('tr th').each(function(i, el) {
      if ($(el).attr('colspan')) {
        count += parseInt($(el).attr('colspan'));
      } else {
        count += 1;
      }
    });
    $(el).attr('colspan', count);
  });
  $('.table-responsive').on('show.bs.dropdown', function () {
    $('.table-responsive').css( "overflow", "inherit" );
  });

  $('.table-responsive').on('hide.bs.dropdown', function () {
    $('.table-responsive').css( "overflow", "auto" );
  })
}

window.collapseIconChange = function() {
  $("[data-toggle='collapse']").each(function(i,el) {
    $(el).click(function() {
      target = $($(el).data('target'));
      children = $(el).find("svg");
      if ($(el).data('parent') && !target.hasClass('show')) {
        $('.fa-caret-square-down').each(function(j, obj) {
          $(obj).removeClass('fa-caret-square-up');
          $(obj).addClass('fa-caret-square-down');
        });
      }
      if (children.hasClass('fa-caret-square-up')) {
        children.removeClass('fa-caret-square-up').addClass('fa-caret-square-down');
      } else {
        children.removeClass('fa-caret-square-down').addClass('fa-caret-square-up');
      }
    });
  });
}

window.colspans = function() {
  $('td.colspan').each(function(i, el) {
    var count = 0
    $(el).closest('table').find('tr th').each(function(i, el) {
      if ($(el).attr('colspan')) {
        count += parseInt($(el).attr('colspan'));
      } else {
        count += 1;
      }
    });
    $(el).attr('colspan', count);
  });
}

window.fakeDateField = function() {
  $(".fake_date_field").each(function(i,el) {
    if ($(el).val()) {
      this.type = 'date';
    }
    $(el).on('focus', function () {
      this.type = 'date';
      this.click();
    });
    $(el).on('focusout', function () {
      if (this.value == '') {
        this.type = 'text';
      }
    });
  });
}

window.initilizeUppy = function() {
  $(".upload_file").on("dragover", function(e) {
    $(this).click();
  });
  if($("#drag-drop-area").length > 0) {
    const Uppy = require('@uppy/core')
    const XHRUpload = require('@uppy/xhr-upload')
    const Dashboard = require('@uppy/dashboard')
    require('@uppy/core/dist/style.css')
    require('@uppy/dashboard/dist/style.css')
    const Italian = require('@uppy/locales/lib/it_IT')
    if ($("#drag-drop-area[data-uppy-max-files]").length) {
      uppy_max_files = $('#drag-drop-area').data("uppy-max-files");
    } else {
      uppy_max_files = 1
    }
    const uppy = Uppy({
      autoProceed: false,
      locale: Italian,
      restrictions: {
        // maxFileSize: 300000,
        maxNumberOfFiles: uppy_max_files,
        minNumberOfFiles: 1
        // allowedFileTypes: ['image/*', 'video/*']
      }
    })
    uppy.use(Dashboard, {
        target: '#drag-drop-area',
        inline: true,
        height: 300
    });
    uppy.use(XHRUpload, {
      endpoint: $('#drag-drop-area').data('url'),
      timeout: 300 * 1000,
      bundle: true
    })
    uppy.on('complete', (result) => { location.reload(); })
    $('.uppy-Dashboard-poweredBy').hide();
  }
}

window.popover = function() {
  $('[data-toggle="popover"]').popover();
}

window.checkAll = function() {
  $("#check_all").click(function(){
    $("input[type=checkbox]").prop('checked', $(this).prop('checked'));
  });
}

window.selectpicker = function() {
  $('.selectpicker').selectpicker();
}

window.toggleFields = function() {
  $("select[data-behaviour='toggle_fields']").each(function(i, el) {
    toggleFieldsVisibility(el);
    $(el).change(function() {
      toggleFieldsVisibility(el);
    });
  });
}

window.toggleFieldsVisibility = function() {
  $("[data-dependency]").each(function(i,el) {
    target = $(this).data("dependency");
    values = $(this).data('dependencyvalue').toString().split(',');
    condition = $(this).data('dependencycondition');
    target_value = $("#" + target).val();
    switch(condition) {
      case 'Not-equals':
        if ($.inArray( target_value, values ) == -1 && target_value != '') {
          $(el).show();
          $(el).find('*').filter(':input:first').prop( "disabled", false );
        } else {
          $(el).hide();
          $(el).find('*').filter(':input:first').prop( "disabled", true );
        }
        break;
      case 'Equals':
        if ($.inArray( target_value, values ) != -1 && target_value != '') {
          $(el).show();
          $(el).find('*').filter(':input:first').prop( "disabled", false );
        } else {
          $(el).hide();
          $(el).find('*').filter(':input:first').prop( "disabled", true );
        }
        break;
      case 'Contains':
        if ( String(target_value).indexOf(String(values)) >= 0 && target_value != '' ) {
          $(el).show();
          $(el).find('*').filter(':input:first').prop( "disabled", false );
        } else {
          $(el).hide();
          $(el).find('*').filter(':input:first').prop( "disabled", true );
        }
      case 'Does not contain':
        if ( String(target_value).indexOf(String(values)) == -1 && target_value != '' ) {
          $(el).show();
          $(el).find('*').filter(':input:first').prop( "disabled", false );
        } else {
          $(el).hide();
          $(el).find('*').filter(':input:first').prop( "disabled", true );
        }
      case 'Starts with':
        if (String(target_value).match("^" + String(values)) && target_value != '') {
          $(el).show();
          $(el).find('*').filter(':input:first').prop( "disabled", false );
        } else {
          $(el).hide();
          $(el).find('*').filter(':input:first').prop( "disabled", true );
        }
      case 'Does not start with':
        if ( String(target_value).match("^" + String(values)) == null && target_value != '') {
          $(el).show();
          $(el).find('*').filter(':input:first').prop( "disabled", false );
        } else {
          $(el).hide();
          $(el).find('*').filter(':input:first').prop( "disabled", true );
        }
      case 'IsNil':
        if (target_value == '' && values == '') {
          $(el).show();
          $(el).find('*').filter(':input:first').prop( "disabled", false );
        } else {
          $(el).hide();
          $(el).find('*').filter(':input:first').prop( "disabled", true );
        }
        break;
      }
  });
}

window.toggles = function() {
  $("[data-behaviour='toggle']").each(function(i, el) {
    var div = $(el);
    div.children('a').on('click', function () {
      var url = $(this).data('url');
      $.ajax({
        type: 'PATCH',
        url: url,
        beforeSend: function() {
          $(this).removeClass('btn-success').removeClass('btn-danger').addClass('btn-warning');
        },
        success: function(data) {
          div.replaceWith(data);
        },
        dataType: 'html'
      });
    });
  });
}

window.tooltip = function() {
  $('[data-toggle="tooltip"]').tooltip();
}

window.spinner = function() {
  $(window).on("load",function(){
    $("#spinner").hide();
  });
  $('[data-spinner="true"]').on('click',function(){
    $("#spinner").show();
  });
}

window.popup = function() {
  $('.flyout').hide();
  $(".popup").each(function(i,el) {
    $(this).hover(function(){
      $(el).find('.flyout').show();
      $(el).find('.description').hide();
    },function(){
      $(el).find('.flyout').hide();
      $(el).find('.description').show();
    });
  });
};

window.inlineUpdate = function() {
  $(".inline_select").each(function(i,el) {
    $(el).change(function() {
      id = $(el).data("id");
      var customer_machine = $(el).closest('.customer_machine');
      if ($(el).data("aggregated-job") == true) {
        url = "/aggregated_jobs/" + id + "/inline_update";
      } else {
        url = "/line_items/" + id + "/inline_update";
      }
      $.ajax({
        type: 'PATCH',
        url: url,
        beforeSend: function() {
          $(el).prop("disabled", true);
        },
        error: function(data) {
          $(el).prop("disabled", false);
          $("#p_" + id).removeClass('alert-success').addClass('alert-danger').fadeIn('slow');
          $("#p_" + id).html('<span>Errore. Riprovare!</span>');
          setTimeout(function() { $("#p_" + id).fadeOut('slow'); }, 3000);
        },
        success: function(data) {
          $(el).prop("disabled", false);
          if (data['code'] == '500') {
            $("#p_" + id).removeClass('alert-success').addClass('alert-danger').html('<span>Errore. Riprovare!</span>');
          } else if (data['code'] == '400') {
            $("#p_" + id).removeClass('alert-success').addClass('alert-danger').html('<span>Prestampa terminata, non è possibile aggiornare il dato.</span>');
          }
          $("#p_" + id).fadeIn('slow');
          setTimeout(function() { $("#p_" + id).fadeOut('slow'); }, 3000);
          location.reload();
        },
        data: {
          value: $(el).val(),
          customer_machine: $(customer_machine).val(),
        },
        dataType: 'json'
      });
    });
  });
}
