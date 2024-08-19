    var checkboxinputs = document.querySelectorAll(".checklist-progressbar input[type='checkbox']");
    var progressbar = document.querySelector('.checklist-progressbar .progressbar-inner');
    var progressbarvalue = document.querySelector('.checklist-progressbar .progressbar-value');
    var progresspercentageNum = 0;
    var progresspercentage = "0%";

    for ( var i = 0, len = checkboxinputs.length; i < len; i++ ) {
    
        var box = checkboxinputs[i];
        if (box.hasAttribute("id")) {
            setupLocalStorage(box);
        }
        
        checkboxinputs[i].addEventListener('click', function(e) {    
            checkNumberofChecked();
            updateProgressbar();
        });
    };
    
    function checkNumberofChecked() {
        var checkedboxes = 0;
        for ( var i = 0, len = checkboxinputs.length; i < len; i++ ) {
            if (checkboxinputs[i].checked) {
            checkedboxes++;
            }; 
        };
        progresspercentageNum = ((checkedboxes / checkboxinputs.length) * 100);
        progresspercentage = ((checkedboxes / checkboxinputs.length) * 100) + "%";
    };
    
    function updateProgressbar() {

        if (progressbar == null) {
            return;
        }
        
        if (progresspercentageNum < 100) {
            progressbar.style.backgroundColor = "blue";
        }
        else {
            progressbar.style.backgroundColor = "green";
            /* "obslab" and "pageTitle" are defined in custom_theme/main.html
             *  obslab refers to extra.obslab in mkdocs.yaml
             */

            dynatrace.sendBizEvent("page_completion", {
                "obslab": obslab,
                "page": pageTitle
            });
        };
        progressbar.style.width = progresspercentage;
        progressbarvalue.innerHTML = Math.round(progresspercentageNum) + "%";
    };
    
    function setupLocalStorage(box) {
        var storageId = box.getAttribute("id");
        var oldVal    = localStorage.getItem(storageId);
        
        if (oldVal == "true") {
            box.checked = true;
        } else {
            box.checked = false;
        };     
        
        box.addEventListener("change", function() {
            localStorage.setItem(storageId, this.checked);

            /* "obslab" is defined in custom_theme/main.html
             * and refers to extra.obslab in mkdocs.yaml
              * "pageTitle" is defined in main.html
              *  it uses the current page title: page.title
             */
            dynatrace.sendBizEvent("progress_report", {
                "obslab": obslab,
                "checkbox_id": this.id,
                "checkbox_checked": this.checked,
                "page": pageTitle,
            });
        });
    };
    
    checkNumberofChecked();
    updateProgressbar();