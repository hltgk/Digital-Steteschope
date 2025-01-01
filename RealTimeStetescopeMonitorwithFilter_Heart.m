clear; clc; % Çalışma alanını ve termineli temizler

% Seri port ve işlem parametrelerini tanımlama
port = "COM3"; % Seri port adı
baudRate = 112500; % Baud hızı
bufferSize = 7000; % Veri tamponunun boyutu
updateInterval = 75; % Grafik güncelleme aralığı
fftUpdateInterval = updateInterval * 10; % FFT güncelleme aralığı
bpmUpdateInterval = fftUpdateInterval * 4; % BPM güncelleme aralığı
delay = 0.00000001; % Döngü gecikmesi (saniye)
Fs = 2000; % Örnekleme frekansı (Hz)
maxFreq = 500; % Maksimum frekans limiti (Hz)

% Veri tamponlarını başlatma
data = zeros(1, bufferSize); % Ham veri tamponu
filteredData = zeros(1, bufferSize); % Filtrelenmiş veri tamponu
tempBuffer = zeros(1, updateInterval); % Geçici tampon matrisi
tempIndex = 1; % Geçici tampon için index

% FFT için frekans ekseni tanımlama
fftPoints = bufferSize / 2; % FFT noktaları
freqAxis = linspace(0, Fs / 2, fftPoints); % Frekans ekseni
freqLimitIndex = find(freqAxis <= maxFreq, 1, 'last'); % Frekans limit indeksi
freqAxis = freqAxis(1:freqLimitIndex); % Frekans eksenini sınırla

pause(0.5); % Başlamadan önce kısa bir duraklama

% Seri portu açma
s = serialport(port, baudRate);

% Grafik arayüzü oluşturma
figure('Name', 'Real-Time Stetescope Monitor with Filter (Heart)', 'Position', [1, 50, 1540, 735], 'UserData', struct('s', s, 'isRunning', false));

% Ham sinyal için grafik oluşturma
subplot(2, 2, 1);
h1 = plot(data, 'LineWidth', 1.5);
title('Real-Time Raw Signal (Heart)');
xlabel('Sample (n)');
ylabel('Signal');
grid on;
set(gca, 'Position', [0.04, 0.64, 0.44, 0.33]);

% Ham sinyal FFT grafiği oluşturma
subplot(2, 2, 2);
h2 = plot(freqAxis, zeros(1, freqLimitIndex), 'LineWidth', 1.5);
title('Real-Time FFT of Raw Signal (Heart)');
xlabel('Frequency (Hz)');
ylabel('Magnitude');
grid on;
set(gca, 'Position', [0.54, 0.64, 0.44, 0.33]);

% Filtrelenmiş sinyal için grafik oluşturma
subplot(2, 2, 3);
h3 = plot(filteredData, 'LineWidth', 2, 'Color', "#D95319");
title('Real-Time Filtered Signal (Heart)');
xlabel('Sample (n)');
ylabel('Signal');
grid on;
set(gca, 'Position', [0.04, 0.21, 0.44, 0.33]);

% Filtrelenmiş sinyal FFT grafiği oluşturma
subplot(2, 2, 4);
h4 = plot(freqAxis, zeros(1, freqLimitIndex), 'LineWidth', 2, 'Color', "#D95319");
title('Real-Time FFT of Filtered Signal (Heart)');
xlabel('Frequency (Hz)');
ylabel('Magnitude');
grid on;
set(gca, 'Position', [0.54, 0.21, 0.44, 0.33]);

% BPM (Kalp Atış Hızı) göstergesi oluşturma
bpmText = uicontrol('Style', 'text', 'Position', [30, 40, 50, 40], 'String', 'BPM: --', 'FontSize', 12, 'FontWeight', 'bold');

% Başlat/Durdur düğmesi oluşturma
startStopButton = uicontrol('Style', 'pushbutton', 'String', 'Start', 'FontSize', 12, 'FontWeight', 'bold', 'Position', [115, 20, 120, 80], 'Callback', @(src, event) toggleStartStop());

% Filtre order için kaydırıcı oluşturma
uicontrol('Style', 'text', 'FontSize', 12, 'FontWeight', 'bold', 'Position', [270, 30, 50, 50], 'String', 'Filter Order');
sliderOrder = uicontrol('Style', 'slider', 'BackgroundColor', [0.8, 0.8, 0.8], 'SliderStep', [1/(10-1), 1/(10-1)],  'Min', 1, 'Max', 10, 'Value', 4, 'Position', [325, 20, 360, 80], 'Tag', 'sliderOrder', 'Callback', @(src, event) updateFilter());
sliderOrderValue = uicontrol('Style', 'text', 'FontSize', 12, 'FontWeight', 'bold', 'Position', [685, 50, 30, 20], 'String', '4', 'Tag', 'sliderOrderValue');

% Alt kesim frekansı için kaydırıcı oluşturma
uicontrol('Style', 'text', 'FontSize', 12, 'FontWeight', 'bold', 'Position', [760, 60, 100, 40], 'String', 'Lower Cutoff (Hz)');
sliderLow = uicontrol('Style', 'slider', 'BackgroundColor', [0.8, 0.8, 0.8], 'Min', 10, 'Max', maxFreq-10, 'Value', 30, 'Position', [880, 65, 580, 30], 'SliderStep', [10/(maxFreq - 10), (10/maxFreq)+0.000835], 'Tag', 'sliderLow', 'Callback', @(src, event) updateFilter());
sliderLowValue = uicontrol('Style', 'text', 'FontSize', 12, 'FontWeight', 'bold', 'Position', [1470, 70, 50, 20], 'String', '30', 'Tag', 'sliderLowValue');

% Üst kesim frekansı için kaydırıcı oluşturma
uicontrol('Style', 'text', 'FontSize', 12, 'FontWeight', 'bold', 'Position', [760, 15, 100, 40], 'String', 'Upper Cutoff (Hz)');
sliderHigh = uicontrol('Style', 'slider', 'BackgroundColor', [0.8, 0.8, 0.8], 'Min', 10, 'Max', maxFreq-10, 'Value', 330, 'Position', [880, 20, 580, 30], 'SliderStep', [10/(maxFreq - 10), (10/maxFreq)+0.000835], 'Tag', 'sliderHigh', 'Callback', @(src, event) updateFilter());
sliderHighValue = uicontrol('Style', 'text', 'FontSize', 12, 'FontWeight', 'bold', 'Position', [1470, 25, 50, 20], 'String', '330', 'Tag', 'sliderHighValue');

% Filtre katsayılarını hesaplama
fcLow = sliderLow.Value;
fcHigh = sliderHigh.Value;
order = round(sliderOrder.Value);
[b, a] = butter(order, [fcLow, fcHigh] / (Fs / 2));
setappdata(gcf, 'FilterCoeffs', struct('b', b, 'a', a));

% Sayaçları başlatma
counter = 0;
fftCounter = 0;
bpmCounter = 0; % BPM güncelleme sayacı

pause(0.5); % Başlamadan önce kısa bir duraklama

% Ana döngü
while isvalid(h1)
    fig = gcf;
    userData = fig.UserData;
    if userData.isRunning
        if s.NumBytesAvailable >= 2
            % Seri porttan veri okuma
            rawBytes = read(s, 2, 'uint8');
            newSample = bitshift(rawBytes(1), 8) + rawBytes(2);
            newSample = newSample - 500;

            % Geçici tampona ekleme
            tempBuffer(tempIndex) = newSample;
            tempIndex = tempIndex + 1;

            if tempIndex > updateInterval
                data = [data(updateInterval + 1:end), tempBuffer];
                coeffs = getappdata(gcf, 'FilterCoeffs');
                filteredData = filter(coeffs.b, coeffs.a, data);

                % Sayaç ve grafik güncellemeleri
                counter = counter + updateInterval;
                fftCounter = fftCounter + updateInterval;
                bpmCounter = bpmCounter + updateInterval;

                % FFT ve BPM kontrolü
                if fftCounter >= fftUpdateInterval
                    fftData = abs(fft(data));
                    fftData = fftData(1:fftPoints);
                    fftData = fftData(1:freqLimitIndex);
                    set(h2, 'YData', fftData);

                    filteredFFT = abs(fft(filteredData));
                    filteredFFT = filteredFFT(1:fftPoints);
                    filteredFFT = filteredFFT(1:freqLimitIndex);
                    set(h4, 'YData', filteredFFT);

                    fftCounter = 0;
                end

                if bpmCounter >= bpmUpdateInterval
                    bpm = calculateBPM(filteredData, Fs);
                    set(bpmText, 'String', sprintf('BPM: %.1f', bpm));
                    bpmCounter = 0;
                end

                set(h1, 'YData', data);
                set(h3, 'YData', filteredData);

                tempBuffer = zeros(1, updateInterval);
                tempIndex = 1;
                drawnow limitrate;
            end
        end
    else
        pause(0.5);
    end
    pause(delay); % Döngü gecikmesi
end

clear; % Çalışma alanını temizler

% Filtre güncelleme fonksiyonu
function updateFilter(~, ~)
    sliderLow = findobj('Tag', 'sliderLow');
    sliderHigh = findobj('Tag', 'sliderHigh');
    sliderOrder = findobj('Tag', 'sliderOrder');
    fcLow = sliderLow.Value;
    fcHigh = sliderHigh.Value;
    order = round(sliderOrder.Value);

    % Yeni filtre katsayılarını hesaplama
    [b, a] = butter(order, [fcLow, fcHigh] / (2000 / 2));
    setappdata(gcf, 'FilterCoeffs', struct('b', b, 'a', a));

    % Kaydırıcı değerlerini güncelleme
    sliderLowValue = findobj('Tag', 'sliderLowValue');
    sliderHighValue = findobj('Tag', 'sliderHighValue');
    sliderOrderValue = findobj('Tag', 'sliderOrderValue');
    set(sliderLowValue, 'String', sprintf('%.1f Hz', fcLow));
    set(sliderHighValue, 'String', sprintf('%.1f Hz', fcHigh));
    set(sliderOrderValue, 'String', sprintf('%d', order));

    % Seri portu temizleme
    fig = gcf;
    userData = fig.UserData;
    if isfield(userData, 's')
        flush(userData.s);
    end
end

% BPM hesaplama fonksiyonu
function bpm = calculateBPM(signal, Fs)
    peakThreshold = mean(signal) + 0.5 * std(signal); % Tepe algılama eşiği
    [~, locs] = findpeaks(signal, 'MinPeakHeight', peakThreshold, 'MinPeakDistance', Fs * 0.5);
    if numel(locs) < 2
        bpm = 0; % Yeterli tepe noktası yoksa BPM sıfır
        return;
    end
    intervals = diff(locs) / Fs; % Tepe noktaları arasındaki süre
    avgInterval = mean(intervals); % Ortalama süre
    bpm = 60 / avgInterval; % BPM hesaplama
end

% Başlat/Durdur fonksiyonu
function toggleStartStop()
    fig = gcf;
    userData = fig.UserData;
    userData.isRunning = ~userData.isRunning; % Çalışma durumunu değiştir
    if userData.isRunning
        set(gcbo, 'String', 'Pause');
        flush(userData.s);
    else
        set(gcbo, 'String', 'Start');
    end
    fig.UserData = userData;
end