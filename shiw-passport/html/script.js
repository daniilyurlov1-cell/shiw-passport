$(document).ready(function() {
    window.addEventListener('message', function(event) {
        const data = event.data;
        
        if (data.action === 'openPassport') {
            openPassport(data.data, data.own, data.showName);
        }
        
        // Скрытие паспорта
        if (data.action === 'hide') {
            $('#passport-container').fadeOut(300);
        }
    });

    function openPassport(passportData, isOwn, showName) {
        // Заполняем данные
        $('#serial').text(passportData.serial || '-');
        $('#firstname').text(passportData.firstname || '-');
        $('#lastname').text(passportData.lastname || '-');
        
        // Пол
        let genderText = '-';
        if (passportData.gender === 0 || passportData.gender === '0') {
            genderText = 'Мужской';
        } else if (passportData.gender === 1 || passportData.gender === '1') {
            genderText = 'Женский';
        }
        $('#gender').text(genderText);
        
        $('#eyecolor').text(passportData.eyecolor || '-');
        $('#religion').text(passportData.religion || '-');
        $('#height').text(passportData.height || '-');
        $('#weight').text(passportData.weight || '-');
        $('#city').text(passportData.city || '-');
        
        // ? Фото персонажа
        if (passportData.photo && passportData.photo !== '') {
            $('#passport-photo').attr('src', passportData.photo);
            $('#passport-photo').show();
        } else {
            // Заглушка если фото нет
            $('#passport-photo').attr('src', 'images/no-photo.png');
            $('#passport-photo').show();
        }
        
        // Обработка ошибки загрузки фото
        $('#passport-photo').on('error', function() {
            $(this).attr('src', 'images/no-photo.png');
        });
        
        // Дата выдачи
        const today = new Date();
        const dateStr = today.getDate().toString().padStart(2, '0') + '.' + 
                        (today.getMonth() + 1).toString().padStart(2, '0') + '.' + 
                        today.getFullYear();
        $('#issueDate').text(dateStr);
        
        // Показываем/скрываем кнопку "Показать"
        if (isOwn) {
            $('#showBtn').show();
        } else {
            $('#showBtn').hide();
            // Показываем от кого получен паспорт
            if (showName) {
                $('#showedBy').text('Показал: ' + showName);
                $('#showedBy').show();
            }
        }
        
        // Показываем паспорт
        $('#passport-container').fadeIn(300);
    }

    // Закрыть паспорт
    $('#closeBtn').click(function() {
        $('#passport-container').fadeOut(300);
        $.post('https://rsg-passport/closePassport', JSON.stringify({}));
    });

    // Показать паспорт
    $('#showBtn').click(function() {
        $('#passport-container').fadeOut(300);
        $.post('https://rsg-passport/showPassport', JSON.stringify({}));
    });

    // Закрыть на ESC
    $(document).keyup(function(e) {
        if (e.key === "Escape") {
            $('#passport-container').fadeOut(300);
            $.post('https://rsg-passport/closePassport', JSON.stringify({}));
        }
    });
});