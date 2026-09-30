<?php
/**
 * Plugin Name: Taminyaran Academy
 * Description: Ultra-light context-aware technical micro-academy for Taminyaran.com.
 * Version: 0.1.1
 * Author: Taminyaran
 */
if (!defined('ABSPATH')) exit;
define('TYA_VER','0.1.1');
define('TYA_URL',plugin_dir_url(__FILE__));
add_action('wp_enqueue_scripts',function(){
 if(is_admin())return;
 wp_enqueue_style('ty-academy',TYA_URL.'assets/academy.css',array(),TYA_VER);
 wp_enqueue_script('ty-academy',TYA_URL.'assets/academy.js',array(),TYA_VER,true);
 wp_localize_script('ty-academy','TYAcademy',array('base'=>TYA_URL.'data/','version'=>TYA_VER));
},99);
add_action('woodmart_after_header',function(){
 if(is_admin())return;
 echo '<section id="ty-academy" dir="rtl" aria-live="polite" hidden><div class="tya-inner"><button class="tya-brand" type="button" aria-label="نکته بعدی"><span class="tya-mic" aria-hidden="true"><svg viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M12 14a3 3 0 0 0 3-3V5a3 3 0 0 0-6 0v6a3 3 0 0 0 3 3Zm5-3a5 5 0 0 1-10 0H5a7 7 0 0 0 6 6.92V21H8v2h8v-2h-3v-3.08A7 7 0 0 0 19 11h-2Z"/></svg></span><span class="tya-name">آکادمی تأمین‌یاران</span><span class="tya-topic"></span></button><div class="tya-copy"><span class="tya-text"></span><button class="tya-next" type="button" aria-label="نکته بعدی">نکته بعدی</button></div></div></section>';
},4);